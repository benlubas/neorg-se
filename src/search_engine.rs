use anyhow::anyhow;
use ignore::WalkBuilder;
use once_cell::sync::Lazy;
use regex::Regex;
use std::io;
use std::path::Path;

use log::{error, info};
use tantivy::collector::TopDocs;
use tantivy::query::QueryParser;
use tantivy::{schema::*, IndexReader};
use tantivy::{Index, IndexWriter, ReloadPolicy};

use std::fs;

#[derive(Debug)]
pub struct ParsedDocument {
    pub title: String,
    pub categories: Vec<String>,
    pub path: String,
    pub body: String,
}

impl ParsedDocument {
    pub fn new(file_path: &str) -> io::Result<ParsedDocument> {
        let contents = fs::read_to_string(file_path)?;
        let mut stripped_contents = contents.clone();

        static METADATA_RE: Lazy<Regex> =
            Lazy::new(|| Regex::new(r"(?ms)\A(\s*@document.meta\s*(.*?)@end\s*)$").unwrap());

        let mut title = "";
        let mut categories: Vec<String> = vec![];
        if let Some((_, [full_meta_tag, metadata])) = METADATA_RE
            .captures_iter(&contents)
            .map(|c| c.extract())
            .next()
        {
            info!("Metadata:\n{metadata}");
            static TITLE_RE: Lazy<Regex> =
                Lazy::new(|| Regex::new(r"(?m)^title\:\s*(.*)$").unwrap());
            if let Some((_, [captured_title])) =
                TITLE_RE.captures_iter(metadata).map(|c| c.extract()).next()
            {
                title = captured_title;
            }

            static CATEGORIES_RE: Lazy<Regex> = Lazy::new(|| {
                Regex::new(r"categories:\s*\[((?s).*?)\]|categories:\s*(\w+)").unwrap()
            });
            categories = CATEGORIES_RE
                .captures_iter(metadata)
                .map(|c| c.extract::<1>().1[0].to_string())
                .collect();
            categories = categories
                .iter()
                .flat_map(|s| s.split_whitespace())
                .map(|s| s.to_string())
                .collect();
            info!("{categories:?}");

            stripped_contents = contents[full_meta_tag.len()..].to_string();
        }

        Ok(ParsedDocument {
            title: title.to_string(),
            categories,
            path: file_path.to_string(),
            body: stripped_contents,
        })
    }
}

pub struct SearchEngine {
    pub data_path: String,
    pub schema: Schema,
    pub index: Option<Index>,
    pub reader: Option<IndexReader>,
}

impl SearchEngine {
    pub fn new(data_path: String) -> SearchEngine {
        let mut schema_builder = Schema::builder();
        schema_builder.add_text_field("title", TEXT);
        schema_builder.add_text_field("categories", TEXT);
        schema_builder.add_text_field("path", TEXT | STORED);
        schema_builder.add_text_field("body", TEXT);
        // TODO: Maybe search for an existing index at the data_path and read it if it exists?
        SearchEngine {
            data_path,
            schema: schema_builder.build(),
            index: None,
            reader: None,
        }
    }

    /// Take a workspaces of files, traverse, parse and add them to the index
    pub fn index(&mut self, ws_path: &str, ws_name: &str) -> tantivy::Result<()> {
        let ws_data_path = self.data_path.to_string() + ws_name;
        // TODO: reuse existing index from disk potentially with cache?
        // Figure out how to determine which files need updating. Is it even a concern? Indexing is
        // very fast.
        if std::path::Path::new(&ws_data_path).exists() {
            let _ = fs::remove_dir_all(&ws_data_path);
        }
        let _ = fs::create_dir_all(&ws_data_path);
        let index = Index::create_in_dir(ws_data_path, self.schema.clone())?;
        let mut index_writer: IndexWriter = index.writer(50_000_000)?;

        // TODO: This should be multithreaded via `.build_parallel()` but there's a really
        // confusing interface to it, and little documentation if any.

        // NOTE: just reading all these and parsing them initially takes a full second for my notes
        // repository. This operation does need to become multithreaded, even though it doesn't
        // block nvim, it will take a while on slower machines with even larger note pools, which
        // isn't ideal.
        let walker = WalkBuilder::new(Path::new(ws_path)).build();
        for result in walker {
            match result {
                Ok(entry) => {
                    info!("File Entry: {entry:?}");
                    let path = entry.path().to_string_lossy();
                    if let Ok(document) = ParsedDocument::new(&path) {
                        info!("Document: {document:?}");
                        // TODO: add these documents to the index now.
                        let mut new_doc = tantivy::TantivyDocument::default();
                        new_doc.add_text(self.schema.get_field("title")?, document.title);
                        for cat in document.categories {
                            new_doc.add_text(self.schema.get_field("categories")?, cat);
                        }
                        new_doc.add_text(self.schema.get_field("path")?, path);
                        new_doc.add_text(self.schema.get_field("body")?, document.body);
                        index_writer.add_document(new_doc)?;
                    }
                }
                Err(err) => error!("{err}"),
            }
        }
        index_writer.commit()?;
        self.index = Some(index);

        Ok(())
    }

    /// Setup the reader. This is a searcher pool that auto reloads when the index is updated.
    /// We're not really making use of it, typically you would have one reader that you acquire
    /// many searchers from; in this case we're no server, we're just using one searcher.
    fn aquire_reader(&mut self) -> tantivy::Result<()> {
        if let Some(index) = &self.index {
            self.reader = Some(
                index
                    .reader_builder()
                    .reload_policy(ReloadPolicy::OnCommitWithDelay)
                    .try_into()?,
            );
        }
        Ok(())
    }

    pub fn query(&mut self, query_str: &str) -> anyhow::Result<Vec<(f32, TantivyDocument)>> {
        self.aquire_reader()?;
        if let Some(reader) = &self.reader {
            // acquiring a searcher is cheap. One searcher should be used per user request.
            let searcher = reader.searcher();

            // Search the title and body fields if the user doesn't specify
            let query_parser = QueryParser::for_index(
                self.index.as_ref().unwrap(),
                vec![
                    self.schema.get_field("title")?,
                    self.schema.get_field("body")?,
                ],
            );

            let query = query_parser.parse_query(query_str)?;
            let top_docs = searcher.search(&query, &TopDocs::with_limit(10))?;
            let mut results: Vec<(f32, TantivyDocument)> = vec![];
            for (score, doc_address) in top_docs {
                let retrieved_doc: TantivyDocument = searcher.doc(doc_address)?;
                let json = retrieved_doc.to_json(&self.schema);
                info!("{score}: {}", json);

                results.push((score, retrieved_doc));
            }

            return Ok(results);
        }

        Err(anyhow!("Failed to aquire reader"))
    }
}

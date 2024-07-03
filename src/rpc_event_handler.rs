use std::sync::mpsc::Receiver;

use log::{error, info, warn};
use neovim_lib::{Neovim, NeovimApi, Session};
use tantivy::schema::*;

use crate::search_engine::SearchEngine;

enum Messages {
    Query,
    Index,
    Unknown(String),
}

impl From<String> for Messages {
    fn from(event: String) -> Self {
        match &event[..] {
            "index" => Messages::Index,
            "query" => Messages::Query,
            _ => Messages::Unknown(event),
        }
    }
}

/// EventHandler receives RPC requests, and maps them to right Spotify and Neovim commands.
pub struct EventHandler {
    nvim: Neovim,
    receiver: Receiver<(String, Vec<neovim_lib::Value>)>,
    search_engine: SearchEngine,
}

impl EventHandler {
    pub fn new() -> EventHandler {
        // unwrap safe because new_parent always returns Ok
        let session = Session::new_parent().unwrap();
        let mut nvim = Neovim::new(session);

        // we have to do this weird thing where we start the thing here so we can ask about the
        // data_path.
        let receiver = nvim.session.start_event_loop_channel();

        let data_path = nvim
            .call_function("stdpath", vec![neovim_lib::Value::String("data".into())])
            .unwrap();
        let data_path = data_path.as_str().unwrap();
        // let data_path = "~/.local/state/nvim/";

        info!("data_path: {data_path}");

        EventHandler {
            nvim,
            receiver,
            search_engine: SearchEngine::new(data_path.to_string()),
        }
    }

    pub fn handle_events(&mut self) {
        for (event, values) in &self.receiver {
            match Messages::from(event) {
                Messages::Query => {
                    info!("We got a query: {values:?}");
                    let queries: Vec<&str> = values.iter().filter_map(|v| v.as_str()).collect();
                    info!("queries: {queries:?}");
                    for q in queries {
                        match self.search_engine.query(q) {
                            Ok(results) => {
                                info!("Query Success!");

                                let str_results: Vec<String> = results
                                    .iter()
                                    .filter_map(|(score, r)| {
                                        if let Ok(field) =
                                            self.search_engine.schema.get_field("path")
                                        {
                                            r.get_all(field)
                                                .next()
                                                .unwrap()
                                                .as_str()
                                                .map(|path| format!("[{score}, \"{path}\"]"))
                                        } else {
                                            None
                                        }
                                    })
                                    .collect();
                                let query_results_str = str_results.join(",");
                                // TODO: surely there is a better way to do sanitization than this
                                let q = q.replace('\'', r"\'");
                                let q = q.replace('"', r#"\""#);
                                let luacall = format!(
                                    "require('neorg_se').show_results('{q}', '[{query_results_str}]')"
                                );
                                info!("{luacall}");
                                self.nvim
                                    .call_function(
                                        "luaeval",
                                        vec![neovim_lib::Value::String(luacall.into())],
                                    )
                                    .unwrap();
                            }
                            Err(e) => error!("Query Error: {e}"),
                        }
                    }
                }
                Messages::Index => {
                    info!("We got an index command");
                    let ws_name = values.first().unwrap().as_str().unwrap();
                    let ws_path = values.get(1).unwrap().as_str().unwrap();
                    info!("{ws_name}, {ws_path}");
                    match self.search_engine.index(ws_path, ws_name) {
                        Ok(_) => {
                            info!("[Index] Success");
                        }
                        Err(e) => {
                            error!("[Index] Failed with error: {e:?}");
                        }
                    }
                }
                Messages::Unknown(ev) => {
                    info!("We got an unknown query: `{ev:?}`");
                    self.nvim
                        .command(&format!("echom 'Unknown command: `{}`'", ev))
                        .unwrap();
                }
            }
        }

        warn!("we're out of the event loop now");
    }

    // Example helper functions

    // // helper function to send current song info to nvim instance.
    // fn echo_curr_song(&mut self, artist_song: (String, String)) {
    //     let song_name = format!("{} - {}", &*artist_song.0, &*artist_song.1);
    //
    //     // commands should never fail when session spawned through parent
    //     // if it does, it's probably best that it is fatal.
    //     self.nvim
    //         .command(&format!("echo \"{}\"", song_name))
    //         .unwrap();
    // }
    //
    // // helper function to find lyrics and send result to nvim instance.
    // fn echo_lyrics(&mut self, artist_song: (String, String)) {
    //     let lyrics = lyrics::find_lyrics(&*artist_song.0, &*artist_song.1);
    //
    //     match lyrics {
    //         Some(lyrics) => {
    //             let lyrics_vec = lyrics.split('\n').map(|s| s.to_owned()).collect();
    //
    //             // If the following commands cannot be executed with a parent
    //             // neovim instance, it probably makes sense to die
    //             self.nvim.command("vsplit lyrics.txt").unwrap();
    //             let buf = self.nvim.get_current_buf().unwrap();
    //             let buf_len = buf.line_count(&mut self.nvim).unwrap();
    //             buf.set_lines(&mut self.nvim, 0, buf_len, true, lyrics_vec)
    //                 .unwrap();
    //         }
    //         None => {
    //             self.nvim
    //                 .command("echo \"Could not find lyrics\"")
    //                 .unwrap();
    //         }
    //     }
    // }
}

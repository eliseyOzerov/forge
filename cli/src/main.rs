mod codegen;
mod strings;

use clap::{Parser, Subcommand, ValueEnum};
use std::path::PathBuf;

#[derive(Parser)]
#[command(name = "forge", about = "Forge CLI — codegen tools for Forge SDK")]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Generate typed string accessors from localization JSON
    Strings {
        #[command(subcommand)]
        action: StringsAction,
    },
}

#[derive(Subcommand)]
enum StringsAction {
    /// Generate typed accessors from a locale JSON file
    Generate {
        /// Path to the source locale JSON file (e.g. en.json)
        #[arg(short, long)]
        input: PathBuf,

        /// Output file path (defaults to stdout)
        #[arg(short, long)]
        output: Option<PathBuf>,

        /// Target platform
        #[arg(short, long, default_value = "swift")]
        platform: Platform,
    },
}

#[derive(Clone, ValueEnum)]
enum Platform {
    Swift,
    // Kotlin,
    // Typescript,
}

fn main() {
    let cli = Cli::parse();

    match cli.command {
        Commands::Strings { action } => match action {
            StringsAction::Generate {
                input,
                output,
                platform,
            } => {
                let file = strings::parser::parse_file(&input).unwrap_or_else(|e| {
                    eprintln!("Error: {e}");
                    std::process::exit(1);
                });

                let result = match platform {
                    Platform::Swift => codegen::swift::generate(&file),
                };

                match output {
                    Some(path) => {
                        std::fs::write(&path, &result).unwrap_or_else(|e| {
                            eprintln!("Error writing {}: {e}", path.display());
                            std::process::exit(1);
                        });
                        println!("Generated {}", path.display());
                    }
                    None => print!("{result}"),
                }
            }
        },
    }
}

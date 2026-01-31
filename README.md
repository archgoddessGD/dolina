![Dolina](readme_assets/dolina_logo_full.svg)

# Dolina

**Dataset Organization, Labeling & Interactive Navigation Application**

> **Etymology:** *Dolina* is the Polish word for "valley." In the context of AI training, it represents the goal of Gradient Descent: navigating the loss landscape to find the deepest valley (the lowest loss).

Dolina is a desktop application built with Godot. It helps manage local datasets by visually aligning files based on their filenames. It fills the gap between file browsers (which are suboptimal for datasets) and database tools (which are too complex for casual users).

## Video Showcase

https://github.com/user-attachments/assets/1ce76094-7c1f-4408-898e-ec743636fd68

## Usage & Dataset Structure

Dolina reads data in two ways.

### 1. Basic Mode

By default, Dolina scans the `data/datasets` directory you select. Every subfolder becomes a column.

* Folder `images/` → Column "IMAGES"
* Folder `captions/` → Column "CAPTIONS"

A basic dataset structure looks like this:

```
.
└── data
    ├── datasets
    │   └── example_dataset_WITHOUT_config
    │       ├── edit_prompts
    │       │   ├── kitty_001.txt
    │       │   └── kitty_002.txt
    │       ├── img_prompts
    │       │   ├── kitty_001.txt
    │       │   └── kitty_002.txt
    │       ├── kitty_control
    │       │   ├── kitty_001.png
    │       │   └── kitty_002.png
    │       ├── kitty_reference
    │       │   └── kitty_001.png
    │       └── kitty_target
    │           ├── kitty_001.png
    │           └── kitty_002.png
    ├── deleted_files
    └── dolina_settings.json

```

![without_config_screenshot](readme_assets/without_config_screenshot.jpg)


### 2. Config Mode

If you want more control, place a `dolina_dataset_config.json` file inside a dataset folder. This lets you map specific system paths to column names manually.

```
.
└── data
    └── datasets
        └── example_dataset_WITH_config
            └── dolina_dataset_config.json

```

Here is an example configuration. In this case, it points to files in the dataset *without* a config shown above. Relative and absolute paths are both supported, so you can copy/paste paths directly from your file manager.

```json
{
	"columns": [
		{
			"name": "IMG EDIT PROMPT",
			"path": "../example_dataset_without_config/edit_prompts"
		},
		{
			"name": "Input",
			"path": "../example_dataset_without_config/kitty_control"
		},
		{
			"name": "Reference",
			"path": "../example_dataset_without_config/kitty_reference"
		},
		{
			"name": "Output",
			"path": "../example_dataset_without_config/kitty_target"

		},
		{
			"name": "TXT2IMG PROMPT",
			"path": "../example_dataset_without_config/img_prompts"
		}
	]
}

```

## Features

* **No Database:** Folders are columns; filenames are IDs. It works directly with your file system.
* **Stem-Based Alignment:** Files from different folders (e.g., `images/001.png` and `tags/001.txt`) are aligned into a single row based on the filename (without extension).
* **Supported Files:** Supports images (`png`, `jpg`, `webp`) and text (`txt`, `md`, `json`).
* **Search:** Search by filename or text content. You can apply different search filters to different columns simultaneously.
* **Safety:** Deleted files are moved to a `deleted_files` folder by default. Permanent deletion is an option.
* **Performance:** A caching system manages VRAM usage, keeping images on nearby pages loaded. VRAM usage for caching can be configured in settings.

### Main Grid View

The main view uses pagination to handle large datasets. The number of items per page can be configured in settings.

* **Columns:** Each column is a subfolder.
* **Rows:** Each row is a unique ID (Stem).
* **Conflict Detection:** If multiple files share the same stem in one column (e.g., `001.png` and `001.jpg`), a warning is displayed.

### Image Viewer

Click a thumbnail to enter fullscreen.

* **Zoom & Pan:** Standard zoom and pan controls.
* **Navigation:** Use arrow keys or on-screen buttons to view related images in the row without exiting fullscreen.

### Text Editor

Edit text directly in the grid preview or open the full editor.

* **Find & Replace:** Includes prev/next matching and "Replace All".
* **Autosave:** Changes save automatically (can be disabled in Settings).

### Side-By-Side View

Compare any two columns in fullscreen.

* **Modes:** Compare Image-to-Image, Text-to-Text, or Image-to-Text.
* **Independent Columns:** Set the left and right panels to display any column you want.
* **Navigation:** Move between rows using buttons or keyboard shortcuts (Up/Down or if cursor is focused on text - Ctrl+Up/Down).

### Automation Dashboard

A visual, no-code batch processor for generating or modifying data using LLMs and vLMs.

* **Visual Prompt Builder:** Add blocks to construct your prompt payload. Mix static text instructions with dynamic data from your existing columns (Text or Images).
* **API Compatibility:** Supports OpenAI-compatible endpoints. I tested it with LMStudio (local), Openrouter and the Google Gemini API but it should work with any provider like OpenAI, Anthropic, Qwen, Deepseek etc.
* **Load Balancing:** You may configure multiple API endpoints/keys with specific weights if you want to distribute requests for more diverse captioning styles.
* **Live Preview:** See exactly what JSON payload will be sent to the API before starting the batch.
* **Templates:** Save your prompt configurations and API settings as templates for reuse.

### Audit Dashboard

A quality control tool designed to detect and sanitize responses (refusals, conversational filler, and boilerplate) from text datasets.

You can can the beginning and end of text files for user-defined phrases:
* *Refusals:* (e.g., "I cannot," "I apologize").
* *Preface:* (e.g., "Sure, here is the code," "Certainly").
* *Postface:* (e.g., "Hope this helps," "Let me know").

* **Review Queue:** Issues are aggregated into a list. Clicking an item instantly opens the text. When a file is opened the list can be navigated up or down from within the text editor.

# EPUB Reader - Flutter E-book Reading Application

A fully-featured EPUB e-book reading tool with bookshelf management, code block display, syntax highlighting, and intelligent interactions.

## Features

### Core Features
- **Bookshelf Management**: Manage your e-book collection with cover display and metadata
- Open and read ePub format e-books
- Chapter navigation and switching (supports multi-level chapter structure)
- Code block display support
- Code syntax highlighting (supports multiple programming languages)
- Responsive interface design
- Supports Android and Windows platforms

### Interactive Features
- **Full-screen Mode**: Immersive reading experience with hidden status bar and navigation bar
- **Gesture Controls**:
  - Tap left/right screen edges (20% area each) for quick page turning
  - Horizontal swipe to turn pages (swipe left for next, right for previous)
  - Tap center of screen to show/hide settings menu
- **Font Adjustment**: Support font size adjustment from 12 to 32
- **Dark Mode**: Day/night theme switching to protect your eyes
- **Search Function**: Full-text search for quick content location
- **Chapter List**: Flat display of all chapters (including sub-chapters) with level indentation
- **Bottom Navigation Bar**: Displays page numbers and navigation buttons, usable in full-screen mode
- **Auto-save**: Automatically saves reading progress and settings, restores on next open

### Bookshelf Features
- **Add to Bookshelf**: Add books from file picker or directly from reader
- **Cover Display**: Automatic extraction and display of book covers from EPUB files
- **Book Details Page**: View detailed information including title, author, reading progress, and more
- **Duplicate Prevention**: Uses MD5 hash to prevent adding duplicate books
- **Reading Progress Tracking**: Automatically tracks and displays last read chapter
- **Quick Access**: One-tap access to continue reading from where you left off
- **Remove Books**: Easy removal of books from bookshelf with confirmation dialog

## Dependencies

This project uses the following main dependencies:

- **epubx**: EPUB file parsing
- **file_picker**: File selector
- **flutter_widget_from_html**: HTML content rendering
- **highlight**: Code syntax highlighting
- **html**: HTML parsing
- **shared_preferences**: Local data storage (saves settings and reading progress)
- **path_provider**: File system path utilities
- **crypto**: MD5 hash calculation for duplicate detection
- **flutter_launcher_icons**: App icon generation tool

## Usage

1. **Install Dependencies**
   ```bash
   flutter pub get
   ```

2. **Run the Application**
   ```bash
   flutter run
   ```

3. **Open ePub Files**
   
   **Method 1: From Home Page**
   - Click the "Select ePub File" button on the main interface
   - Choose the .epub file you want to read from your device
   - Optionally add to bookshelf when prompted
   - The app will automatically load and display the book content
   
   **Method 2: From Bookshelf**
   - Click "My Bookshelf" button or bookmark icon
   - Browse your book collection with cover previews
   - Tap any book to view details
   - Click "Open Book" to start reading

4. **Bookshelf Operations**
   - **View Bookshelf**: Click the bookmark icon in top-right corner or "My Bookshelf" button
   - **Add Books**: 
     - From home page: Select file → Choose "Add to Bookshelf"
     - From reader: Tap bookmark icon in app bar
   - **View Book Details**: Tap any book card to see:
     - Book cover (extracted from EPUB or default gradient)
     - Title and author information
     - Reading progress
     - Last read time
     - File MD5 hash
   - **Open Book**: Click "Open Book" button in details page
   - **Remove Book**: Click delete icon in details page or book card
   - **Refresh**: Pull down to refresh or use refresh button

5. **Reading Operations**
   - **Page Turning Methods**:
     - Tap left edge of screen (20% area) → Previous chapter
     - Tap right edge of screen (20% area) → Next chapter
     - Swipe left → Next chapter
     - Swipe right → Previous chapter
     - Use bottom navigation bar arrow buttons
   - **Settings Menu**: Tap the center area of the screen to pop up a centered menu, including:
     - Font size adjustment (12-32)
     - Dark mode toggle
     - Full-text search
     - Chapter list browsing
     - Full-screen mode toggle
     - Bottom navigation bar visibility toggle (controls whether to show page numbers and navigation buttons)
   - **Chapter Navigation**: Click the list icon in the top-right corner or access chapter list from the menu
   - **Exit Full-screen**: Press the back button in full-screen mode to exit first
   - **Bottom Navigation Bar**:
     - Displays current chapter page number (e.g., 5 / 20)
     - Provides quick buttons for previous/next chapter
     - Usable in full-screen mode
     - Can be shown/hidden via the "Bottom Navigation Bar" option in settings menu

6. **Persistence Features**
   - Automatically saves reading progress (chapter position)
   - Automatically saves font size settings
   - Automatically saves dark mode preference
   - Automatically saves bottom navigation bar visibility setting
   - Automatically restores all settings when opening the same file next time
   - Settings for different files are saved independently without interference

## Code Block Support

The reader can properly identify and display code blocks in ePub files, including:

- Automatic language detection (via `class="language-xxx"` or `class="lang-xxx"`)
- Syntax highlighting for multiple programming languages:
  - Java, Python, JavaScript, C/C++
  - HTML, CSS, SQL
  - And other languages supported by highlight.js
- Dark theme code display
- Selectable code text

## Project Structure

```
lib/
├── main.dart                      # Application entry point and home page
├── epub_viewer.dart               # Main ePub reader component
├── models/
│   ├── bookshelf_item.dart        # Bookshelf data model
│   └── flat_chapter.dart          # Chapter data model
├── services/
│   ├── bookshelf_service.dart     # Bookshelf management service
│   ├── epub_parser_service.dart   # EPUB parsing service
│   ├── preferences_service.dart   # Settings persistence service
│   └── search_service.dart        # Search functionality service
└── widgets/
    ├── bookshelf_page.dart        # Bookshelf grid view
    ├── book_detail_page.dart      # Book details page
    ├── reader_content.dart        # Reader content display
    ├── reader_navigation_bar.dart # Bottom navigation bar
    ├── reader_settings_menu.dart  # Settings menu
    ├── chapter_list_panel.dart    # Chapter list panel
    ├── search_result_panel.dart   # Search results panel
    └── code_block_widget.dart     # Code block display component
```

## Notes

### Android Permissions

When using on Android devices, you need to grant storage permissions in system settings to access ePub files.

### Windows Developer Mode

When running on Windows, you need to enable Developer Mode to support plugin symbolic links:
1. Open Settings
2. Go to "Update & Security" > "Developer options"
3. Enable "Developer Mode"

## Technical Implementation

### Code Highlighting Implementation

The code block component uses the `highlight` package for syntax analysis and applies appropriate colors based on different syntax elements:

- Keywords: Blue
- Strings: Orange
- Comments: Green
- Numbers: Light green
- Function names: Yellow
- Class names: Cyan
- Variable names: Light blue

### HTML Rendering

Uses the `flutter_widget_from_html` package to render HTML content in EPUB files, and handles code block elements through custom widget builders.

### Data Persistence

Uses `shared_preferences` for local data storage:
- Generates unique storage keys based on file name hash values
- Automatically saves user's reading progress and personalized settings
- Fully automated without manual user operation

### Bookshelf Storage

Books are stored in the application documents directory:
- **Book Files**: Copied to `epub_books/` with MD5-based filenames
- **Cover Images**: Stored in `epub_books/covers/` as JPG files
- **Metadata**: Saved in SharedPreferences as JSON
- **Duplicate Detection**: MD5 hash prevents adding the same book twice

### App Configuration

#### Modify App Name
- **Android**: Edit `android:label` in `android/app/src/main/AndroidManifest.xml`
- **Windows**: Edit `FileDescription` and `ProductName` in `windows/runner/Runner.rc`

## Future Improvements

- [ ] Support more file formats (PDF, MOBI, TXT, etc.)
- [ ] Add annotation and highlighting features
- [ ] Support tree-structured table of contents display (collapsible/expandable)
- [ ] Add reading statistics (reading time, progress percentage, daily reading volume, etc.)
- [ ] Cloud sync for reading progress and bookshelf
- [ ] Support custom themes and color schemes
- [ ] Add text-to-speech (TTS) reading function
- [ ] Support automatic landscape/portrait orientation adaptation
- [ ] Support multi-language interface switching
- [ ] Export notes and annotations feature
- [ ] Bookshelf categories and tags
- [ ] Offline download and cache management
- [ ] Book search within bookshelf
- [ ] Sort books by various criteria (date added, last read, title, etc.)

## License

MIT License

## Contributing

Issues and Pull Requests are welcome!

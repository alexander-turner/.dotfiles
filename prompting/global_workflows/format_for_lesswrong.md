# Format for LessWrong

Convert a markdown file from TurnTrout.com format to LessWrong-compatible format.

## Steps

1. **Remove YAML frontmatter**: Delete everything between the opening `---` and closing `---` (inclusive).

2. **Convert custom callouts to standard markdown** (use bold extremely sparingly):
   - `> [!quote]` → Simple blockquote with attribution at end using italics (e.g., `_Author, Source_`)
   - `> [!success]`, `> [!warning]`, `> [!info]`, `> [!idea]`, `> [!question]` → Use bold only for standalone section labels (e.g., `**Label.**`) or italics for inline labels (e.g., `_Label._`)
   - `> [!thanks]` → `**Thanks.**` followed by content
   - Remove the `> [!type]` line and adjust remaining blockquote content as needed
   - **Important**: Minimize bold usage - only use for standalone labels like "Thanks", "Clarification", etc.

3. **Convert definition lists to italic headers**:
   - Replace definition list syntax (term followed by `: description`) with italic headers
   - Example: `Term\n: Description` → `_Term._ Description` or `_Term:_ Description`

4. **Replace internal links with full URLs**:
   - Find all markdown links starting with `](/`
   - Replace `](/` with `](https://turntrout.com/`
   - Command: `sed -i '' 's|\](\/|\](https://turntrout.com/|g' filename.md`

## Style guidelines

- **Use bold extremely sparingly** - only for standalone section labels like "Thanks", "Clarification", etc.
- Put quote attributions at the end of blockquotes in italics
- Use simple blockquotes without bold headers
- Convert definition lists to italic text followed by content
- Prefer italics over bold in most cases

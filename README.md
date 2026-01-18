# Lexicon Translate Action

Automatically translate all Xcode String Catalogs (`.xcstrings`) in your repository using [Autoglot](https://autoglot.app).

## Features

- Automatically finds all `.xcstrings` files in your repo
- Translates multiple files in parallel
- Supports glob patterns for file selection
- Works with any iOS/macOS project structure

## Usage

### Translate all files in repo

```yaml
name: Translate

on:
  push:
    paths: ['**/*.xcstrings']
  workflow_dispatch:

jobs:
  translate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Translate all xcstrings
        uses: xzebra/autoglot@main
        with:
          api-key: ${{ secrets.AUTOGLOT_API_KEY }}
          languages: 'de,fr,ja,es,zh-Hans'

      - name: Commit changes
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add -A
          git diff --staged --quiet || git commit -m "Update translations"
          git push
```

### Translate specific files

```yaml
- uses: xzebra/autoglot@main
  with:
    api-key: ${{ secrets.AUTOGLOT_API_KEY }}
    file: 'MyApp/Resources/Localizable.xcstrings'
    languages: 'de,fr,ja'
```

### Translate with glob pattern

```yaml
- uses: xzebra/autoglot@main
  with:
    api-key: ${{ secrets.AUTOGLOT_API_KEY }}
    file: '**/Localizable.xcstrings'
    languages: 'de,fr'
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `api-key` | Your Autoglot API key | Yes | - |
| `file` | Path or glob pattern. Empty = find all | No | (all files) |
| `languages` | Comma-separated target languages | Yes | - |
| `api-url` | Autoglot API URL | No | `https://api.autoglot.app` |
| `parallel` | Number of parallel translations | No | `4` |

## Outputs

| Output | Description |
|--------|-------------|
| `files-translated` | Number of files translated |
| `total-characters` | Total characters translated |
| `total-strings` | Total strings translated |

## Getting an API Key

1. Sign up at [autoglot.app](https://autoglot.app)
2. Go to [Dashboard > API Keys](https://autoglot.app/dashboard/api-keys)
3. Create a new API key
4. Add it to your repository secrets as `AUTOGLOT_API_KEY`

## Supported Languages

`bg`, `cs`, `da`, `de`, `el`, `en`, `en-GB`, `en-US`, `es`, `et`, `fi`, `fr`, `fr-FR`, `hu`, `id`, `it`, `ja`, `ko`, `lt`, `lv`, `nb`, `nl`, `pl`, `pt-BR`, `pt-PT`, `ro`, `ru`, `sk`, `sl`, `sv`, `tr`, `uk`, `zh`, `zh-Hans`

## Example: Create PR for review

```yaml
name: Translate (PR)

on:
  push:
    branches: [main]
    paths: ['**/*.xcstrings']

jobs:
  translate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Translate
        id: translate
        uses: xzebra/autoglot@main
        with:
          api-key: ${{ secrets.AUTOGLOT_API_KEY }}
          languages: 'de,fr,ja,es,ko,zh-Hans'
          parallel: 6

      - name: Create Pull Request
        uses: peter-evans/create-pull-request@v5
        with:
          title: 'Update translations'
          body: |
            Automated translation update.

            - Files: ${{ steps.translate.outputs.files-translated }}
            - Strings: ${{ steps.translate.outputs.total-strings }}
            - Characters: ${{ steps.translate.outputs.total-characters }}
          commit-message: 'chore: update translations'
          branch: translations-update
          delete-branch: true
```

## Pricing

| Plan | Characters/month | Price |
|------|------------------|-------|
| Free | 10,000 | $0 |
| Pro | 100,000 | $19.99/mo |
| Team | 500,000 | $79.99/mo |

Upgrade at [autoglot.app/dashboard/billing](https://autoglot.app/dashboard/billing)

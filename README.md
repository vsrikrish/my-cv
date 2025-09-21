# Academic CV Generator

A reproducible and modular system for generating academic CVs from structured data. The CV automatically updates when data changes and maintains consistent formatting across multiple document types.

**[View Current CV](https://jdossgollin.github.io/my-cv/Doss-Gollin-CV.pdf)** | **[Homepage](https://jdossgollin.github.io)** | **[Lab Website](https://dossgollin-lab.github.io)**

## Goals

This system prioritizes reproducibility through version-controlled data and automated builds. Content is modular - you update YAML files rather than wrestling with LaTeX code. GitHub Actions handles the compilation and publishing automatically when data changes. The same data source generates multiple document types including full CV, biosketch, and grants documents.

## How It Works

CV content lives in structured YAML files covering education, grants, publications, and other sections. Jinja2 templates render this data into LaTeX documents. When you push changes, GitHub Actions automatically compiles PDFs and publishes them to GitHub Pages. The system generates both public documents (full CV) and private specialized documents from the same data source.

## Quick Start

```bash
# Setup environment
conda env create -f environment.yml
conda activate cv

# Generate CV
python generate_cv.py
```

The system uses two submodules:

- Public bibliography repository for publications
- Private data repository for CV content

## GitHub Actions Setup

For the automated CV generation to work, you need to configure a Personal Access Token for accessing private submodules:

1. Go to GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Generate new token with `repo` scope (full repository access)
3. Add it as a repository secret named `PAT_TOKEN` in your repository settings (Settings → Secrets and variables → Actions)

The GitHub Actions workflow requires this token to access the private `my-cv-data` submodule during the build process.

## Customization

Fork this repository and adapt the templates and configuration for your own automated CV system. The framework separates content management from document formatting, making it easy to maintain and update your academic CV over time.

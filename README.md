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

## Customization

Fork this repository and adapt the templates and configuration for your own automated CV system. The framework separates content management from document formatting, making it easy to maintain and update your academic CV over time.

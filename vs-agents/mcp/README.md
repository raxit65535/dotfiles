# MCP Scaffolding

This folder contains starter templates for Model Context Protocol server setup.

## Included

- `servers.example.json`: multi-server template
- `server-filesystem.example.json`: minimal filesystem server example

## How to Use

1. Copy an example to a local file (for example `servers.local.json`).
2. Fill command, args, and environment values.
3. Keep secrets out of git-tracked files.
4. Start with read-only capabilities first.

## Recommended Initial Servers

- filesystem (restricted path)
- git/github read-oriented tooling
- docs/web retrieval tools

## Safety Guidelines

- Avoid broad filesystem access in early experiments.
- Prefer explicit allowlisted paths.
- Store API tokens in environment variables, not files.

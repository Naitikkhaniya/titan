# Titan Tooling Guide

This document describes the tools planned for Titan and the reasons they have been chosen for a local DevOps platform.

## Tool Selection Principles

- Must be free and open source.
- Must run locally on WSL Ubuntu 26.04.
- Must support reproducibility, automation, or observability.
- Must align with a learning-oriented DevOps portfolio.

## Suggested Tools and Their Purpose

### Git

Purpose: source control, versioning, branch workflows.

- Manage code, configs, and documentation.
- Support collaboration patterns even in a solo portfolio project.
- Enable tracking of changes to the local DevOps environment.

### Bash / Shell Scripts

Purpose: automate environment setup, local workflows, and developer tasks.

- Provide reproducible bootstrapping of the WSL environment.
- Encapsulate common commands for developers.
- Serve as the first layer of automation.

### GNU Make

Purpose: provide a simple task runner and orchestration layer.

- Define consistent local workflows with `make` targets.
- Create command abstractions for setup, validation, and cleanup.
- Keep development and operations steps documented in code.

### Local Package Managers and Installers

Purpose: manage dependencies and environment packages.

- Use `apt`, `curl`, or local package managers for installing tools.
- Keep dependencies explicit in documentation.
- Avoid cloud-based package services beyond Linux package repositories.

### Local Logging and Observability Tools

Purpose: monitor local process behavior and capture logs.

- Start with simple CLI tools like `journalctl`, `htop`, and `grep`.
- Extend with local dashboards or log aggregation later.
- Focus on visibility into local applications and scripts.

### Testing and Validation Tools

Purpose: verify local configurations and infrastructure behavior.

- Use shell-based checks, `bash` scripts, or `pytest` for example validations.
- Validate local service start-up, config parameters, and environment readiness.
- Keep tests lightweight and portable.

## Recommended Tooling Approach

1. Start with documentation and planning, not implementation.
2. Choose the smallest viable tool for each layer.
3. Keep workflows explicit so each tool’s role is easy to understand.
4. Iterate documentation as the implementation becomes more concrete.

## Future Tool Candidates

The following tool categories are useful for later phases, but are not yet implemented:

- Local service deployment orchestrators (non-containerized patterns).
- CLI-based metrics and log collectors.
- Infrastructure-as-code runners or interpreters for local resource definitions.
- Secret and environment configuration managers.

## Notes

Titan will avoid commercial cloud services completely. All tools are chosen for their local compatibility and ability to teach DevOps principles in a self-contained environment.

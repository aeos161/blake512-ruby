# Native extension layout

`upstream/` contains byte-identical source and CC0 notices pinned in
`UPSTREAM.md`. It is an auditable reference snapshot, not yet a Ruby extension.
The upstream C file includes a CLI `main` and self-tests. Phase 3 will exclude
those from extension compilation, add a binding and `extconf.rb`, and document
any local patch. No extension is registered in the gemspec yet.

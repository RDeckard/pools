## [Unreleased]

- Namespace all classes under `Pools::` (`Pools::ThreadPool`,
  `Pools::RactorPool`, `Pools::RactorWorker`) and move them under `lib/pools/`.
- Migrate `RactorPool`/`RactorWorker` to the `Ractor::Port` API (Ruby >= 4.0).
- `RactorPool` now distributes jobs round-robin and collects every outcome,
  capturing job exceptions instead of crashing the worker.
- Fix multi-argument jobs in `RactorPool#schedule`.
- Replace `RactorWorker`'s class variable with a closure over the pool and drop
  the redundant logger Ractor.
- Add specs for `RactorPool`.
- Fill in gemspec metadata and require Ruby >= 4.0.
- Update RuboCop (and `rubocop-performance`/`rubocop-rspec`) to versions
  compatible with Ruby 4.0; refresh `.rubocop.yml` and `Gemfile.lock`.

## [0.1.0] - 2022-02-27

- Initial release

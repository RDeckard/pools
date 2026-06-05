# frozen_string_literal: true

require_relative "lib/pools/version"

Gem::Specification.new do |spec|
  spec.name = "pools"
  spec.version = Pools::VERSION
  spec.authors = ["Gabriel"]
  spec.email = ["rdeckard.gt@gmail.com"]

  spec.summary = "Lightweight thread and Ractor pools for I/O-bound and CPU-bound work."
  spec.description = "Pools provides two complementary concurrency abstractions: a ThreadPool " \
                     "for I/O-bound work (built on a thread-safe queue with error collection) and " \
                     "a RactorPool for CPU-bound work (true parallelism on top of the Ractor::Port API)."
  spec.homepage = "https://github.com/RDeckard/pools"
  spec.required_ruby_version = ">= 4.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end

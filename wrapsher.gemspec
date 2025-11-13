# frozen_string_literal: true

require_relative 'lib/wrapsher/version'

Gem::Specification.new do |spec|
  spec.name = 'wrapsher'
  spec.version = Wrapsher::VERSION
  spec.authors = ['Mermaidpurse Admin']
  spec.email = ['admin@mermaidpurse.org']
  spec.license = 'MPL-2.0'

  spec.summary = 'Wrapsher programming language compiler and tools'
  spec.description = <<~DESC
    Wrapsher is a familiar and reasonably ergonomic programming language
    that compiles to pure POSIX-compliant sh for execution.
  DESC
  spec.homepage = 'https://github.com/mermaidpurse/wrapsher'
  spec.required_ruby_version = '>= 3.0.0'

  spec.metadata['allowed_push_host'] = "TODO: Set to your gem server 'https://example.com'"

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/mermaidpurse/wrapsher'
  spec.metadata['changelog_uri'] = 'https://github.com/mermaidpurse/wrapsher/tree/main/CHANGELOG.md'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git appveyor Gemfile])
    end
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'logger'
  spec.add_dependency 'parslet', '~> 2.0.0'
  spec.add_development_dependency 'json'
  spec.add_development_dependency 'pry', '~> 0.14'
end

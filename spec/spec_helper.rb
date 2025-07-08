# frozen_string_literal: true

require "wrapsher"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

# Stringify leaves of parse tree
def stringify(item)
  if item.respond_to?(:to_ary)
    item.map { |e| stringify(e) }
  elsif item.respond_to?(:to_hash)
    Hash[item.map { |k, v| [k, stringify(v)] }]
  elsif item.respond_to?(:to_str)
    item.to_str
  else
    item
  end
end


# frozen_string_literal: true

require_relative 'wrapsher/cli'
require_relative 'wrapsher/compiler'
require_relative 'wrapsher/parser'
require_relative 'wrapsher/node'
require_relative 'wrapsher/syntax'
require_relative 'wrapsher/transform'
require_relative 'wrapsher/generator'
require_relative 'wrapsher/program_tables'
require_relative 'wrapsher/version'

module Wrapsher
  class Error < StandardError; end
  # Your code goes here...
end

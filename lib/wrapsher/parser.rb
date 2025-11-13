# frozen_string_literal: true

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2025 Mermaidpurse

require 'json'
require 'logger'
require 'parslet'
require 'wrapsher'

module Wrapsher
  class Parser
    def initialize(logger: nil, level: nil)
      @logger = logger || Logger.new($stderr)
      @logger.level = level || :DEBUG
    end

    def parsetext(text)
      Wrapsher::Syntax.new.parse(text)
    rescue Parslet::ParseFailed => e
      @logger.error(e.parse_failure_cause.ascii_tree)
      raise
    end

    def parse(filename)
      text = File.read(filename)
      parsetext(text)
    end
  end
end

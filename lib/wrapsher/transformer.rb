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
  # Transform parse AST
  class Transformer
    def initialize(logger: nil, level: nil)
      @logger = logger || Logger.new($stderr)
      @logger.level = level || :DEBUG
    end

    def transform(ast)
      Wrapsher::Transform.new.apply(ast)
    end
  end
end

# frozen_string_literal: true

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2025 Mermaidpurse

require 'mustache'

module Wrapsher
  # "Macro" expander for compiler convenience. This is experimental
  # and purely internal--this is not meant to resemble any future
  # macro facility for wrapsher; it is a mere convenience for the
  # compiler codegen to ease the generation of AST for generated code
  # snippets.
  class Macro
    def initialize(macro)
      @macro = macro
    end

    def ast(data)
      expanded = Mustache.render(@macro, data)
      parsed = Wrapsher::Parser.new.parsetext(expanded)
      Wrapsher::Transformer.new.transform(parsed)
    end
  end
end

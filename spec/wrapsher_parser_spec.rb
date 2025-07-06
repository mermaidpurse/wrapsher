# frozen_string_literal: true

RSpec.describe Wrapsher::Parser do

  it "parses some wrapsher" do
    source = <<~EOF
    module ex
    meta author 'dev@mermaidpurse.org'
    use version 0
    type vector list
    EOF
    parser = Wrapsher::Parser.new()
  program = stringify(parser.parsetext(source)).flatten
  expect(program).to eq([
          { module: 'ex' },
          { meta: { meta_field: 'author', meta_data: { single_quoted: 'dev@mermaidpurse.org' } } },
          { use_version: '0' },
          { type: {name: 'vector', store_type: 'list' } }
        ])
  end

  it "parses a function definition" do
    source = <<~EOF
    int add(int a, int b) {
      a + b
    }
    EOF
    parser = Wrapsher::Parser.new()
    program = stringify(parser.parsetext(source)).flatten
    expect(program).to eq([
      {
        fun_statement: {
          signature: {
            type: 'int',
            name: 'add',
            arg_definitions: [
              {
                type: 'int',
                name: 'a'
              },
              {
                type: 'int',
                name: 'b'
              }
            ]
          },
          body: [
            {
              fun_call: {
                name: 'plus',
                fun_args: [
                  { var_ref: 'a' },
                  { var_ref: 'b' }
                ]
              }
            }
          ]
        }
      }
    ])
  end
end

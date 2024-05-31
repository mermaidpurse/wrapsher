# frozen_string_literal: true

RSpec.describe Wrapsher::Parser do

  it "parses some wrapsher" do
    source = <<-EOF
module ex
meta author 'dev@mermaidpurse.org'
use version 0
type vector
EOF
    parser = Wrapsher::Parser.new()
    program = stringify(parser.parsetext(source))
    expect(program).to eq([
                            { module: 'ex' },
                            { meta_field: 'author', meta_data: { single_quoted: 'dev@mermaidpurse.org' } },
                            { version: '0' },
                            { type: 'vector' }
                          ])
  end

  it "parses a function definition" do
  source = <<-EOF
int add(int a, int b) {
  a + b
}
EOF
    parser = Wrapsher::Parser.new()
    program = stringify(parser.parsetext(source))
    expect(program).to eq([
                            { fun_definition: {
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
                                body: {
                                  primary_op: {
                                    left: {
                                      var_ref: 'a'
                                    },
                                    operator: '+',
                                    right: {
                                      var_ref: 'b'
                                    }
                                  }
                                }
                              }
                            }
                          ])
  end
end

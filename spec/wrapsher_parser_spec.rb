# frozen_string_literal: true

def test_fun(body)
  body = [body] unless body.is_a?(Array)
  [{
    fun_statement: {
      signature: {
        type: 'bool',
        name: 'test',
        arg_definitions: nil,
      },
      body: body
    }
  }]
end

RSpec.describe Wrapsher::Parser do
  it "parses an empty string" do
    source = <<~'EOF'
    bool test(){
      ''
    }
    EOF
    program = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(program).to eq(
      test_fun([
          { string_term: { single_quoted: '' } }
          ]))
  end

  it "parses a throw expression" do
    source = <<~'EOF'
    bool test() {
      throw 'No such program'
    }
    EOF
    program = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(program).to eq(
      test_fun([
          {
            fun_call: {
              name: 'throw',
              fun_args: [
                string_term('No such program')
              ]
            }
          }
        ]))
  end

  it "parses a try/catch block" do
    source = <<~'EOF'
    bool test() {
      try {
        x = 1
      } catch e {
        throw e
      }
    }
    EOF
    program = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(program).to eq(
      test_fun([
          {
            try_block: {
              keyword_try: 'try',
              try_body: [
                { assignment: { var: 'x', rvalue: { int_term: '1' } } }
              ],
              catch: {
                var: 'e',
                keyword_catch: 'catch',
                catch_body: [
                  {
                    fun_call: {
                      name: 'throw',
                      fun_args: [
                        { var_ref: 'e' }
                      ]
                    }
                  }
                ]
              }
            }
          }
        ]))
  end

  it "parses line comments at the top level" do
    source = <<~'EOF'
    # Intro to function
    # Second comment
    bool test() {
      false
    }
    EOF
    program = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(program).to eq(
      [
        { comment: ' Intro to function' },
        { comment: ' Second comment' }
      ] + test_fun([{ bool_term: 'false' }])
      )
  end

  it "parses line comments in a function", skip: 'TODO: fix line comments in blocks' do
    source = <<~'EOF'
    bool test() {
      # Intro to function
      false
    }
    EOF
    program = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(program).to eq(
      test_fun([
          { comment: ' Intro to function' },
          { bool_term: 'false'}
        ]))
  end

  it "parses block ends with trailing whitespace", skip: 'TODO: fix blocks with trailing whitespace' do
    source = <<~'EOF'
    bool test() {
      false
    } 
    EOF
    program = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(program).to eq(
      test_fun([
          { bool_term: 'false' }
        ]))
  end

  it "parses negative ints", skip: 'TODO: fix parsing negative ints' do
    source = <<~'EOF'
    bool test() {
      -10
    }
    EOF
    program = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(program).to eq(
      test_fun([
          { int_term: '-10' }
        ]))
  end

  it "parses strings" do
    source = <<~'EOF'
    bool test() {
      '\''
      '\\back'
      '\'\''
    }
    EOF
    program = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(program).to eq(
      test_fun([
          string_term("\\'"),
          string_term("\\\\back"),
          string_term("\\'\\'")
        ]))
  end

  it "parses an empty map" do
    source = <<~EOF
    bool test() {
      [:]
    }
    EOF
    program = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(program).to eq(
      test_fun([
          {
            fun_call: {
              name: 'new',
              fun_args: [{ var_ref: 'map' }]
            }
          }
        ]))
  end

  it "parses an empty map in a function call" do
    source = <<~'EOF'
    bool test() {
      y._x(p, [:])
    }
    EOF
    program = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(program).to eq(
      test_fun([
          {
            fun_call: {
              name: '_x',
              fun_args: [
                { var_ref: 'y' },
                { var_ref: 'p' },
                {
                  fun_call: {
                    name: 'new',
                    fun_args: [{ var_ref: 'map' }]
                  }
                }
              ]
            }
          }
        ]))
  end

  it "parses a pair in an expression" do
    source = <<~'EOF'
    bool test() {
      p = 'key1': 'value1'
    }
    EOF
    program = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(program).to eq(
      test_fun([
         {
            assignment: {
              var: 'p',
              rvalue: {
                fun_call: {
                  name: 'from_kv',
                  fun_args: [
                    { var_ref: 'pair' },
                    string_term('key1'),
                    string_term('value1')
                  ]
                }
              }
            }
          }
        ]))
  end

  it "parses a pair in a complex expression", skip: 'TODO: fix precedence of pair operator' do
    source = <<~'EOF'
    bool test() {
      p == 'key1': 'value1'
    }
    EOF
    program = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(program).to eq(
      test_fun([
          {
            fun_call: {
              name: 'eq',
              fun_args: [
                { var_ref: 'p' },
                {
                  fun_call: {
                    name: 'from_kv',
                    fun_args: [
                      { var_ref: 'pair' },
                      string_term('key1'),
                      string_term('value1')
                    ]
                  }
                }
              ]
            }
          }
        ]))
  end

  it "parses a pair in an expression with chains", skip: 'TODO: fix pair operator precedence' do
    source = <<~'EOF'
    bool test() {
      m.head() == 'key1': 'value1'
    }
    EOF
    program = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(program).to eq(
      test_fun([
          {
            fun_call: {
              name: 'eq',
              fun_args: [
                {
                  fun_call: {
                    name: 'head',
                    fun_args: [
                      { var_ref: 'm' }
                    ]
                  }
                },
                {
                  fun_call: {
                    name: 'from_kv',
                    fun_args: [
                      { var_ref: 'pair' },
                      string_term('key1'),
                      string_term('value1')
                    ]
                  }
                }
              ]
            }
          }
        ]))
  end

  it "parses a pair" do
    source = <<~EOF
    bool test() {
      'key1': 'value1'
    }
    EOF
    program = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(program).to eq(
      test_fun([
          {
            fun_call: {
              name: 'from_kv',
              fun_args: [
                { var_ref: 'pair' },
                string_term('key1'),
                string_term('value1')
              ]
            }
          }
        ]))
  end

  it "parses a map" do
    source = <<~EOF
    bool test() {
      ['key1': 'value1', 'key2': 'value2']
    }
    EOF
    program = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(program).to eq(
      test_fun([
          {
            fun_call: {
              name: 'from_pairlist',
              fun_args: [
                { var_ref: 'map' },
                {
                  fun_call: {
                    name: 'push',
                    fun_args: [
                      {
                        fun_call: {
                          name: 'push',
                          fun_args: [
                            {
                              fun_call: {
                                name: 'new',
                                fun_args: [{ var_ref: 'list' }]
                              }
                            },
                            {
                              fun_call: {
                                name: 'from_kv',
                                fun_args: [
                                  { var_ref: 'pair' },
                                  string_term('key1'),
                                  string_term('value1')
                                ]
                              }
                            }
                          ]
                        }
                      },
                      {
                        fun_call: {
                          name: 'from_kv',
                          fun_args: [
                            { var_ref: 'pair' },
                            string_term('key2'),
                            string_term('value2')
                          ]
                        }
                      }
                    ]
                  }
                }
              ]
            }
          }
          ]))
    end

  it "evaluates != as a chain" do
    source = <<~EOF
    bool test() {
      a != b
    }
    EOF
    program = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(program).to eq(
      test_fun([
          {
            fun_call: {
              name: 'not',
              fun_args: {
                fun_call: {
                  name: 'eq',
                  fun_args: [{ var_ref: 'a' }, { var_ref: 'b' }]
                }
              }
            }
          }
        ]))
  end

  it "evaluates >= as a chain" do
    source = <<~EOF
    bool test() {
      a >= b
    }
    EOF
    program = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(program).to eq(
      test_fun([
          {
            fun_call: {
              name: 'not',
              fun_args: {
                fun_call: {
                  name: 'lt',
                  fun_args: [{ var_ref: 'a' }, { var_ref: 'b' }]
                }
              }
            }
          }
        ]))
  end

  it "parses an anonymous function" do
    source = <<~EOF
    bool test() {
      bool fun (int a, int b) {
        a == b
      }
    }
    EOF
    program = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(program).to eq(
      test_fun([
          {
            lambda: {
              signature: {
                type: 'bool',
                arg_definitions: [
                  { type: 'int', name: 'a' },
                  { type: 'int', name: 'b' }
                ]
              },
              body: [
                {
                  fun_call: {
                    name: 'eq',
                    fun_args: [{ var_ref: 'a' }, { var_ref: 'b' }]
                  }
                }
              ]
            }
          }
        ]))
  end

  it "parses an anonymous function in a single line" do
    source = <<~EOF
    bool test() {
      bool fun (int a, int b) { a + b; a == b }
    }
    EOF
    program = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(program).to eq(
      test_fun([
          {
            lambda: {
              signature: {
                type: 'bool',
                arg_definitions: [
                  { type: 'int', name: 'a' },
                  { type: 'int', name: 'b' }
                ]
              },
              body: [{
                  fun_call: {
                    name: 'plus',
                    fun_args: [{ var_ref: 'a' }, { var_ref: 'b' }]
                  }
                }, {
                  fun_call: {
                    name: 'eq',
                    fun_args: [{ var_ref: 'a' }, { var_ref: 'b' }]
                  }
                }
              ]
            }
          }
        ]))
  end

  it "parses an anonymous function in an assignment" do
    source = <<~EOF
    bool test() {
      f = bool fun (int a, int b) { a == b }
    }
    EOF
    program = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(program).to eq(
      test_fun([
          {
            assignment: {
              var: 'f',
              rvalue: {
                lambda: {
                  signature: {
                    type: 'bool',
                    arg_definitions: [
                      { type: 'int', name: 'a' },
                      { type: 'int', name: 'b' }
                    ]
                  },
                  body: {
                    fun_call: {
                      name: 'eq',
                      fun_args: [{ var_ref: 'a' }, { var_ref: 'b' }]
                    }
                  }
                }
              }
            }
          }
        ]))
  end

  it "parses an anonymous function in an expression" do
    source = <<~EOF
    bool test() {
      l.filter(bool fun (string s) { s.length() > 0 }, other)
    }
    EOF
    program = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(program).to eq(
      test_fun([
          {
            fun_call: {
              name: 'filter',
              fun_args: [
                { var_ref: 'l' },
                {
                  lambda: {
                    signature: {
                      type: 'bool',
                      arg_definitions: { type: 'string', name: 's' }
                    },
                    body: {
                      fun_call: {
                        name: 'gt',
                        fun_args: [
                          {
                            fun_call: {
                              name: 'length',
                              fun_args: [{ var_ref: 's' }]
                            }
                          },
                          { int_term: '0' }
                        ]
                      }
                    }
                  }
                },
                { var_ref: 'other' }
              ]
            }
          }
        ]))
  end

  it "parses a subscript" do
    source = <<~EOF
    bool test() {
      x[0]
    }
    EOF
    program = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(program).to eq(
      test_fun([
          {
            fun_call: {
              name: 'at',
              fun_args: [{var_ref: 'x'}, {int_term: '0'}]
            }
          }
        ]))
  end

  it "parses an empty list" do
    source = <<~EOF
    bool test(){
      [ ]
    }
    EOF
    program = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(program).to eq(
      test_fun([
          {
            fun_call: {
              name: 'new',
              fun_args: [{var_ref: 'list'}]
            }
          }
        ]))
  end

  it "parses an additive expression", skip: 'TODO: chain operators' do
    source = <<~'EOF'
    bool test() {
      x.to_string() + ' ' + ' '
    }
    EOF
    program = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    # plus(plus(to_string(x), string_term(' ')), to_string(y))
    expect(program).to eq(
      test_fun([
          {
            fun_call: {
              name: 'plus',
              fun_args: [
                {
                  fun_call: {
                    name: 'plus',
                    fun_args: [
                      {
                        fun_call: {
                          name: 'to_string',
                          fun_args: [
                            {var_ref: 'x'}
                          ]
                        }
                      },
                      string_term(' ')
                    ]
                  }
                },
                {
                  fun_call: {
                    name: 'to_string',
                    fun_args: [
                      { var_ref: 'y' }
                    ]
                  }
                }
              ]
            }
          }
        ]))
  end

  it "parses a list literal" do
    source = <<~EOF
    bool test() {
      [1, 2, 3]
    }
    EOF
    program = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(program).to eq(
      test_fun([
          {
            fun_call: {
              name: 'push',
              fun_args: [
                {
                  fun_call: {
                    name: 'push',
                    fun_args: [
                      {
                        fun_call: {
                          name: 'push',
                          fun_args: [
                            {
                              fun_call: {
                                name: 'new',
                                fun_args: [
                                  { var_ref: 'list' }
                                ]
                              }
                            },
                            { int_term: '1' }
                          ]
                        }
                      },
                      { int_term: '2' }
                    ]
                  }
                },
                { int_term: '3' }
              ]
            }
          }
        ]))
  end

  it "parses a list with expressions" do
    source = <<~EOF
    bool test() {
      x = [0, a.to_string(), not b, 3 - 4]
    }
    EOF
    program = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(program).to eq(
      test_fun([
          {
            assignment: {
              var: 'x',
              rvalue:
              {:fun_call=>
                {:fun_args=>
                  [{:fun_call=>
                      {:fun_args=>
                        [{:fun_call=>
                            {:fun_args=>
                              [{:fun_call=>
                                  {:fun_args=>
                                    [{:fun_call=>
                                        {:fun_args=>[{:var_ref=>"list"}],
                                          :name=>"new"}},
                                      {:int_term=>"0"}],
                                    :name=>"push"}},
                                {:fun_call=>
                                  {:fun_args=>[{:var_ref=>"a"}],
                                    :name=>"to_string"}}],
                              :name=>"push"}},
                          {:fun_call=>{:fun_args=>[{:var_ref=>"b"}], :name=>"not"}}],
                        :name=>"push"}},
                    {:fun_call=>
                      {:fun_args=>[{:int_term=>"3"}, {:int_term=>"4"}],
                        :name=>"minus"}}],
                  :name=>"push"}}
            }
          }]))
  end

  it "parses a function definition" do
    source = <<~EOF
    int add(int a, int b) {
      a + b
    }
    EOF
    parser = Wrapsher::Parser.new
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

end

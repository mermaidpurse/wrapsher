# frozen_string_literal: true

def test_fun(body)
  body = [body] unless body.is_a?(Array)
  [{
    fun_statement: {
      signature: {
        type: 'bool',
        name: 'test',
        arg_definitions: nil
      },
      body: body
    }
  }]
end

# rubocop:disable Metrics/BlockLength
RSpec.describe 'parser/transform' do
  it 'parses a struct spec' do
    source = <<~'SOURCE'
      type x ['name': string, 'is_ok': bool]
    SOURCE
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    program = Wrapsher::Transformer.new.transform(ast)
    expect(program).to eq(
      [
        {
          type: {
            name: 'x',
            struct_spec: {
              list_term: {
                lbracket: '[',
                elements: [
                  {
                    pair: {
                      key: { string_term: { single_quoted: 'name' } },
                      value: { var_ref: 'string' }
                    }
                  },
                  {
                    pair: {
                      key: { string_term: { single_quoted: 'is_ok' } },
                      value: { var_ref: 'bool' }
                    }
                  }
                ]
              }
            }
          }
        }
      ]
    )
  end

  it 'parses a multiline struct spec' do
    source = <<~'SOURCE'
      type x [
        'name': string,
        'is_ok': bool
       ]
    SOURCE
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    program = Wrapsher::Transformer.new.transform(ast)
    expect(program).to eq(
      [
        {
          type: {
            name: 'x',
            struct_spec: {
              list_term: {
                lbracket: '[',
                elements: [
                  {
                    pair: {
                      key: { string_term: { single_quoted: 'name' } },
                      value: { var_ref: 'string' }
                    }
                  },
                  {
                    pair: {
                      key: { string_term: { single_quoted: 'is_ok' } },
                      value: { var_ref: 'bool' }
                    }
                  }
                ]
              }
            }
          }
        }
      ]
    )
  end

  it 'parses a function call' do
    source = <<~'SOURCE'
      bool test() {
        length('one')
      }
    SOURCE
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(ast).to eq(
      test_fun([
                 {
                   fun_call: {
                     name: 'length',
                     fun_args: { string_term: { single_quoted: 'one' } }
                   }
                 }
               ])
    )
  end

  it 'parses a postfix on a subscript' do
    source = <<~'SOURCE'
      bool test() {
        x[0].length()
      }
    SOURCE
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(ast).to eq(
      test_fun([
                 {
                   chain: {
                     receiver: { var_ref: 'x' },
                     calls: [
                       {
                         subscript: {
                           index: { int_term: '0' }
                         }
                       },
                       {
                         postfix: {
                           fun_call: {
                             name: 'length',
                             fun_args: nil
                           }
                         }
                       }
                     ]
                   }
                 }
               ])
    )
    program = Wrapsher::Transformer.new.transform(ast)
    expect(program).to eq(
      test_fun([
                 {
                   fun_call: {
                     name: 'length',
                     fun_args: [
                       {
                         fun_call: {
                           name: 'at',
                           fun_args: [{ var_ref: 'x' }, { int_term: '0' }]
                         }
                       }
                     ]
                   }
                 }
               ])
    )
  end

  it 'parses an expression with linebreaks' do
    source = <<~'SOURCE'
      bool test() {
        x = [
          0,
          1,
          2
        ]
      }
    SOURCE
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(ast).to eq(
      test_fun(
        [
          {
            assignment: {
              var: 'x',
              rvalue: {
                list_term: {
                  lbracket: '[',
                  elements: [
                    { int_term: '0' },
                    { int_term: '1' },
                    { int_term: '2' }
                  ]
                }
              }
            }
          }
        ]
      )
    )
  end

  it 'parses a lol' do
    source = <<~'SOURCE'
      bool test() {
        x = [
          0,
          [0, 1],
          [0, 1, 2]
        ]
      }
    SOURCE
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(ast).to eq(
      test_fun(
        [
          {
            assignment: {
              var: 'x',
              rvalue: {
                list_term: {
                  lbracket: '[',
                  elements: [
                    { int_term: '0' },
                    { list_term: { lbracket: '[', elements: [{ int_term: '0' }, { int_term: '1' }] } },
                    { list_term: { lbracket: '[', elements: [{ int_term: '0' }, { int_term: '1' }, { int_term: '2' }] } }
                  ]
                }
              }
            }
          }
        ]
      )
    )
  end

  it 'parses a lom' do
    source = <<~'SOURCE'
      bool test() {
        x = [
          ['one': 1, 'two': 2],
          [:],
          ['THREE': 3]
        ]
      }
    SOURCE
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(ast).to eq(
      test_fun(
        [
          {
            assignment: {
              var: 'x',
              rvalue: {
                list_term: {
                  lbracket: '[',
                  elements: [
                    {
                      list_term: {
                        lbracket: '[',
                        elements: [
                          { pair: { key: string_term('one'), value: { int_term: '1' } } },
                          { pair: { key: string_term('two'), value: { int_term: '2' } } }
                        ]
                      }
                    },
                    { empty_map_term: '[:]' },
                    {
                      list_term: {
                        lbracket: '[',
                        elements: {
                          pair: { key: string_term('THREE'), value: { int_term: '3' } }
                        }
                      }
                    }
                  ]
                }
              }
            }
          }
        ]
      )
    )
  end

  it 'parses a mol' do
    source = <<~'SOURCE'
      bool test() {
        x = [
          'one': [0, 1],
          'two': [0, 1, 2]
        ]
      }
    SOURCE
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(ast).to eq(
      test_fun(
        [
          {
            assignment: {
              var: 'x',
              rvalue: {
                list_term: {
                  lbracket: '[',
                  elements: [
                    {
                      pair: {
                        key: string_term('one'),
                        value: {
                          list_term: {
                            lbracket: '[',
                            elements: [
                              { int_term: '0' },
                              { int_term: '1' }
                            ]
                          }
                        }
                      }
                    },
                    {
                      pair: {
                        key: string_term('two'),
                        value: {
                          list_term: {
                            lbracket: '[',
                            elements: [
                              { int_term: '0' },
                              { int_term: '1' },
                              { int_term: '2' }
                            ]
                          }
                        }
                      }
                    }
                  ]
                }
              }
            }
          }
        ]
      )
    )
  end

  it 'parses a dispatch table', skip: 'TODO: fix lambda parse in map' do
    source = <<~'SOURCE'
      bool test() {
        x = [
          'add5': int fun (int i) { i + 5 },
          'sub3': int fun (int i) { i - 3 }
        ]
      }
    SOURCE
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(ast).to eq(
      test_fun(
        [
          {
            assignment: {
              var: 'x',
              rvalue: {
                list_term: {
                  lbracket: '[',
                  elements: [
                    {
                      pair: {
                        key: string_term('add5'),
                        value: {
                          lambda: {
                            signature: {
                              type: 'int',
                              arg_definitions: {
                                type: 'int',
                                name: 'i'
                              }
                            },
                            body: {
                              additive_op: {
                                left: { var_ref: 'i' },
                                operator: '+',
                                right: { int_term: '5' }
                              }
                            }
                          }
                        }
                      }
                    },
                    {
                      pair: {
                        key: string_term('sub3'),
                        value: {
                          lambda: {
                            signature: {
                              type: 'int',
                              arg_definitions: {
                                type: 'int',
                                name: 'i'
                              }
                            },
                            body: {
                              additive_op: {
                                left: { var_ref: 'i' },
                                operator: '-',
                                right: { int_term: '3' }
                              }
                            }
                          }
                        }
                      }
                    }
                  ]
                }
              }
            }
          }
        ]
      )
    )
  end

  it 'parses a chain' do
    source = <<~'SOURCE'
      bool test() {
        i.to_string().quote()
      }
    SOURCE
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(ast).to eq(
      test_fun([
                 {
                   chain: {
                     receiver: { var_ref: 'i' },
                     calls: [
                       { postfix: { fun_call: { name: 'to_string', fun_args: nil } } },
                       { postfix: { fun_call: { name: 'quote', fun_args: nil } } }
                     ]
                   }
                 }
               ])
    )
    program = Wrapsher::Transformer.new.transform(ast)
    expect(program).to eq(
      test_fun([
                 {
                   fun_call: {
                     name: 'quote',
                     fun_args: [
                       {
                         fun_call: {
                           name: 'to_string',
                           fun_args: [
                             { var_ref: 'i' }
                           ]
                         }
                       }
                     ]
                   }
                 }
               ])
    )
  end

  it 'parses an empty string' do
    source = <<~'SOURCE'
      bool test() {
        ''
      }
    SOURCE
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(ast).to eq(
      test_fun([
                 { string_term: { single_quoted: [] } }
               ])
    )
    program = Wrapsher::Transformer.new.transform(ast)
    expect(program).to eq(
      test_fun([
                 { string_term: { single_quoted: '' } }
               ])
    )
  end

  it 'parses a throw expression' do
    source = <<~'SOURCE'
      bool test() {
        throw 'No such program'
      }
    SOURCE
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(ast).to eq(
      test_fun([{ throw: string_term('No such program') }])
    )
    program = Wrapsher::Transformer.new.transform(ast)
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
               ])
    )
  end

  it 'parses a try/catch block' do
    source = <<~'SOURCE'
      bool test() {
        try {
          x = 1
        } catch e {
          throw e
        }
      }
    SOURCE
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(ast).to eq(
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
                           throw: { var_ref: 'e' }
                         }
                       ]
                     }
                   }
                 }
               ])
    )
  end

  it 'parses line comments at the top level' do
    source = <<~'SOURCE'
      # Intro to function
      # Second comment
      bool test() {
        false
      }
    SOURCE
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(ast).to eq(
      [
        { comment: ' Intro to function' },
        { comment: ' Second comment' }
      ] + test_fun([{ bool_term: 'false' }])
    )
  end

  it 'parses line comments in a function' do
    source = <<~'SOURCE'
      bool test() {
        # Intro to function
        false
      }
    SOURCE
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(ast).to eq(
      test_fun([
                 { comment: ' Intro to function' },
                 { bool_term: 'false' }
               ])
    )
  end

  it 'parses block ends with trailing whitespace' do
    source = <<~'SOURCE'
      bool test() {
        false
      }
    SOURCE
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(ast).to eq(
      test_fun([
                 { bool_term: 'false' }
               ])
    )
  end

  it 'parses negative ints' do
    source = <<~'SOURCE'
      bool test() {
        -10
      }
    SOURCE
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(ast).to eq(
      test_fun([
                 { int_term: '-10' }
               ])
    )
  end

  it 'parses strings' do
    source = <<~'SOURCE'
      bool test() {
        '\''
        '\\back'
        '\'\''
      }
    SOURCE
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(ast).to eq(
      test_fun([
                 string_term("\\'"),
                 string_term('\\\\back'),
                 string_term("\\'\\'")
               ])
    )
  end

  it 'parses an empty map' do
    source = <<~SOURCE
      bool test() {
        [:]
      }
    SOURCE
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    program = stringify(Wrapsher::Transformer.new.transform(ast)).flatten
    expect(program).to eq(
      test_fun([{ empty_map_term: '[:]' }])
    )
  end

  it 'parses an empty map in a function call' do
    source = <<~'SOURCE'
      bool test() {
        y._x(p, [:])
      }
    SOURCE
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    program = stringify(Wrapsher::Transformer.new.transform(ast)).flatten
    expect(program).to eq(
      test_fun(
        [
          {
            fun_call: {
              name: '_x',
              fun_args: [
                { var_ref: 'y' },
                { var_ref: 'p' },
                { empty_map_term: '[:]' }
              ]
            }
          }
        ]
      )
    )
  end

  it 'parses a pair in an expression' do
    source = <<~'SOURCE'
      bool test() {
        p = 'key1': 'value1'
      }
    SOURCE
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    program = stringify(Wrapsher::Transformer.new.transform(ast)).flatten
    expect(program).to eq(
      test_fun(
        [
          {
            assignment: {
              var: 'p',
              rvalue: {
                pair: {
                  key: { string_term: { single_quoted: 'key1' } },
                  value: { string_term: { single_quoted: 'value1' } }
                }
              }
            }
          }
        ]
      )
    )
  end

  it 'parses a boolean expression' do
    source = <<~'SOURCE'
      bool test() {
        x and y or not z
      }
    SOURCE
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(ast).to eq(
      test_fun([
                 {
                   boolean_op: [
                     { left: { var_ref: 'x' } },
                     { operator: 'and', right: { var_ref: 'y' } },
                     { operator: 'or', right: {
                       boolean_not: {
                         subject: { var_ref: 'z' }
                       }
                     } }
                   ]
                 }
               ])
    )
    program = stringify(Wrapsher::Transformer.new.transform(ast)).flatten
    expect(program).to eq(
      test_fun([
                 {
                   fun_call: {
                     name: 'or',
                     fun_args: [
                       {
                         fun_call: {
                           name: 'and',
                           fun_args: [
                             { var_ref: 'x' },
                             { var_ref: 'y' }
                           ]
                         }
                       },
                       {
                         fun_call: {
                           name: 'not',
                           fun_args: [
                             { var_ref: 'z' }
                           ]
                         }
                       }
                     ]
                   }
                 }
               ])
    )
  end

  it 'parses a pair in a complex expression' do
    source = <<~'SOURCE'
      bool test() {
        p == 'key1': 'value1'
      }
    SOURCE
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(ast).to eq(
      test_fun([
                 {
                   comparison: {
                     left: { var_ref: 'p' },
                     operator: '==',
                     right: {
                       pair: {
                         key: string_term('key1'),
                         value: string_term('value1')
                       }
                     }
                   }
                 }
               ])
    )
  end

  it 'parses a pair in an expression with chains' do
    source = <<~'SOURCE'
      bool test() {
        m.head() == 'key1': 'value1'
      }
    SOURCE
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    program = stringify(Wrapsher::Transformer.new.transform(ast)).flatten
    expect(program).to eq(
      test_fun(
        [
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
                  pair: {
                    key: string_term('key1'),
                    value: string_term('value1')
                  }
                }
              ]
            }
          }
        ]
      )
    )
  end

  it 'parses a pair' do
    source = <<~SOURCE
      bool test() {
        'key1': 'value1'
      }
    SOURCE
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    program = stringify(Wrapsher::Transformer.new.transform(ast)).flatten
    expect(program).to eq(
      test_fun(
        [
          {
            pair: {
              key: string_term('key1'),
              value: string_term('value1')
            }
          }
        ]
      )
    )
  end

  it 'parses a map' do
    source = <<~SOURCE
      bool test() {
        ['key1': 'value1', 'key2': 'value2']
      }
    SOURCE
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(ast).to eq(
      test_fun(
        [
          {
            list_term: {
              lbracket: '[',
              elements: [
                {
                  pair: {
                    key: string_term('key1'),
                    value: string_term('value1')
                  }
                },
                {
                  pair: {
                    key: string_term('key2'),
                    value: string_term('value2')
                  }
                }
              ]
            }
          }
        ]
      )
    )
  end

  it 'evaluates != as a chain' do
    source = <<~SOURCE
      bool test() {
        a != b
      }
    SOURCE
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    program = stringify(Wrapsher::Transformer.new.transform(ast)).flatten
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
               ])
    )
  end

  it 'evaluates >= as a chain' do
    source = <<~SOURCE
      bool test() {
        a >= b
      }
    SOURCE
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    program = stringify(Wrapsher::Transformer.new.transform(ast)).flatten
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
               ])
    )
  end

  it 'parses an anonymous function' do
    source = <<~SOURCE
      bool test() {
        bool fun (int a, int b) {
          a == b
        }
      }
    SOURCE
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    program = stringify(Wrapsher::Transformer.new.transform(ast)).flatten
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
               ])
    )
  end

  it 'parses an anonymous function in a single line' do
    source = <<~SOURCE
      bool test() {
        bool fun (int a, int b) { a + b; a == b }
      }
    SOURCE
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(ast).to eq(
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
                         additive_op: [
                           { left: { var_ref: 'a' } },
                           { operator: '+', right: { var_ref: 'b' } }
                         ]
                       },
                       {
                         comparison: {
                           left: { var_ref: 'a' },
                           operator: '==',
                           right: { var_ref: 'b' }
                         }
                       }
                     ]
                   }
                 }
               ])
    )
    program = stringify(Wrapsher::Transformer.new.transform(ast)).flatten
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
                     }]
                   }
                 }
               ])
    )
  end

  it 'parses an anonymous function in an assignment' do
    source = <<~SOURCE
      bool test() {
        f = bool fun (int a, int b) { a == b }
      }
    SOURCE
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    program = stringify(Wrapsher::Transformer.new.transform(ast)).flatten
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
               ])
    )
  end

  it 'parses an anonymous function in an expression' do
    source = <<~SOURCE
      bool test() {
        l.filter(bool fun (string s) { s.length() > 0 }, other)
      }
    SOURCE
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    program = stringify(Wrapsher::Transformer.new.transform(ast)).flatten
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
               ])
    )
  end

  it 'parses a subscript' do
    source = <<~SOURCE
      bool test() {
        x[0]
      }
    SOURCE
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(ast).to eq(
      test_fun([
                 {
                   chain: {
                     receiver: { var_ref: 'x' },
                     calls: [
                       { subscript: { index: { int_term: '0' } } }
                     ]
                   }
                 }
               ])
    )
    program = stringify(Wrapsher::Transformer.new.transform(ast)).flatten
    expect(program).to eq(
      test_fun([
                 {
                   fun_call: {
                     name: 'at',
                     fun_args: [{ var_ref: 'x' }, { int_term: '0' }]
                   }
                 }
               ])
    )
  end

  it 'parses a multidimensional subscript' do
    source = <<~SOURCE
      bool test() {
        x[0]['foo']
      }
    SOURCE
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(ast).to eq(
      test_fun([
                 {
                   chain: {
                     receiver: { var_ref: 'x' },
                     calls: [
                       { subscript: { index: { int_term: '0' } } },
                       { subscript: { index: string_term('foo') } }
                     ]
                   }
                 }
               ])
    )
    program = stringify(Wrapsher::Transformer.new.transform(ast)).flatten
    expect(program).to eq(
      test_fun([
                 {
                   fun_call: {
                     name: 'at',
                     fun_args: [
                       {
                         fun_call: {
                           name: 'at',
                           fun_args: [{ var_ref: 'x' }, { int_term: '0' }]
                         }
                       },
                       string_term('foo')
                     ]
                   }
                 }
               ])
    )
  end

  it 'parses a subscript on an expression' do
    source = <<~SOURCE
      bool test() {
        x.y()['foo']
      }
    SOURCE
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(ast).to eq(
      test_fun([
                 {
                   chain: {
                     receiver: { var_ref: 'x' },
                     calls: [
                       { postfix: { fun_call: { name: 'y', fun_args: nil } } },
                       { subscript: { index: string_term('foo') } }
                     ]
                   }
                 }
               ])
    )
    program = stringify(Wrapsher::Transformer.new.transform(ast)).flatten
    expect(program).to eq(
      test_fun([
                 {
                   fun_call: {
                     name: 'at',
                     fun_args: [
                       {
                         fun_call: {
                           name: 'y',
                           fun_args: [{ var_ref: 'x' }]
                         }
                       },
                       string_term('foo')
                     ]
                   }
                 }
               ])
    )
  end

  it 'parses an empty list' do
    source = <<~SOURCE
      bool test(){
        [ ]
      }
    SOURCE
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    program = stringify(Wrapsher::Transformer.new.transform(ast)).flatten
    expect(program).to eq(
      test_fun(
        [
          {
            list_term: {
              lbracket: '[',
              elements: nil
            }
          }
        ]
      )
    )
  end

  it 'parses an additive expression' do
    source = <<~'SOURCE'
      bool test() {
        x.to_string() + ' ' + ' '
      }
    SOURCE
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    program = stringify(Wrapsher::Transformer.new.transform(ast)).flatten
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
                                   { var_ref: 'x' }
                                 ]
                               }
                             },
                             string_term(' ')
                           ]
                         }
                       },
                       string_term(' ')
                     ]
                   }
                 }
               ])
    )
  end

  it 'parses a list literal' do
    source = <<~SOURCE
      bool test() {
        [1, 2, 3]
      }
    SOURCE
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    program = stringify(Wrapsher::Transformer.new.transform(ast)).flatten
    expect(program).to eq(
      test_fun(
        [
          {
            list_term: {
              lbracket: '[',
              elements: [
                { int_term: '1' },
                { int_term: '2' },
                { int_term: '3' }
              ]
            }
          }
        ]
      )
    )
  end

  it 'parses a list with expressions' do
    source = <<~SOURCE
      bool test() {
        x = [0, a.to_string(), not b, 3 - 4]
      }
    SOURCE
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    program = stringify(Wrapsher::Transformer.new.transform(ast)).flatten
    expect(program).to eq(
      test_fun(
        [
          {
            assignment: {
              var: 'x',
              rvalue: {
                list_term: {
                  lbracket: '[',
                  elements: [
                    { int_term: '0' },
                    {
                      fun_call: {
                        name: 'to_string',
                        fun_args: [
                          { var_ref: 'a' }
                        ]
                      }
                    },
                    {
                      fun_call: {
                        name: 'not',
                        fun_args: [
                          { var_ref: 'b' }
                        ]
                      }
                    },
                    {
                      fun_call: {
                        name: 'minus',
                        fun_args: [
                          { int_term: '3' },
                          { int_term: '4' }
                        ]
                      }
                    }
                  ]
                }
              }
            }
          }
        ]
      )
    )
  end

  it 'parses a return call' do
    source = <<~'SOURCE'
      bool test() {
        if x > 0 {
          return false
        }
      }
    SOURCE
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    program = stringify(Wrapsher::Transformer.new.transform(ast)).flatten
    expect(program).to eq(
      test_fun([
                 {
                   conditional: {
                     keyword_if: 'if',
                     condition: {
                       fun_call: {
                         name: 'gt',
                         fun_args: [
                           { var_ref: 'x' },
                           { int_term: '0' }
                         ]
                       }
                     },
                     then: [
                       {
                         return: {
                           keyword_return: 'return',
                           return_value: {
                             bool_term: 'false'
                           }
                         }
                       }
                     ]
                   }
                 }
               ])
    )
  end

  it 'parses a break call' do
    source = <<~'SOURCE'
      bool test() {
        while x > 0 {
          break
        }
      }
    SOURCE
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    program = stringify(Wrapsher::Transformer.new.transform(ast)).flatten
    expect(program).to eq(
      test_fun([
                 {
                   while: {
                     keyword_while: 'while',
                     condition: {
                       fun_call: {
                         name: 'gt',
                         fun_args: [
                           { var_ref: 'x' },
                           { int_term: '0' }
                         ]
                       }
                     },
                     loop_body: [
                       { break: 'break' }
                     ]
                   }
                 }
               ])
    )
  end

  it 'parses a continue call' do
    source = <<~'SOURCE'
      bool test() {
        while x > 0 {
          continue
        }
      }
    SOURCE
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    program = stringify(Wrapsher::Transformer.new.transform(ast)).flatten
    expect(program).to eq(
      test_fun([
                 {
                   while: {
                     keyword_while: 'while',
                     condition: {
                       fun_call: {
                         name: 'gt',
                         fun_args: [
                           { var_ref: 'x' },
                           { int_term: '0' }
                         ]
                       }
                     },
                     loop_body: [
                       { continue: 'continue' }
                     ]
                   }
                 }
               ])
    )
  end

  it 'parses a while loop' do
    source = <<~'SOURCE'
      bool test() {
        while x > 0 {
          true
        }
      }
    SOURCE
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    program = stringify(Wrapsher::Transformer.new.transform(ast)).flatten
    expect(program).to eq(
      test_fun([
                 {
                   while: {
                     keyword_while: 'while',
                     condition: {
                       fun_call: {
                         name: 'gt',
                         fun_args: [
                           { var_ref: 'x' },
                           { int_term: '0' }
                         ]
                       }
                     },
                     loop_body: [{ bool_term: 'true' }]
                   }
                 }
               ])
    )
  end

  it 'parses a function definition' do
    source = <<~SOURCE
      int add(int a, int b) {
        a * b
      }
    SOURCE
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(ast).to eq([
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
                                multiplicative_op: [
                                  { left: { var_ref: 'a' } },
                                  { operator: '*', right: { var_ref: 'b' } }
                                ]
                              }
                            ]
                          }
                        }
                      ])
    program = stringify(Wrapsher::Transformer.new.transform(ast)).flatten
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
                                      name: 'times',
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

  it 'parses a conditional' do
    source = <<~'SOURCE'
      bool test() {
        if x > 100 {
          true
        }
      }
    SOURCE
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(ast).to eq(
      test_fun([
                 conditional: {
                   keyword_if: 'if',
                   condition: {
                     comparison: {
                       left: { var_ref: 'x' },
                       operator: '>',
                       right: { int_term: '100' }
                     }
                   },
                   then: [{ bool_term: 'true' }]
                 }
               ])
    )
  end

  it 'parses an if-else block' do
    source = <<~'SOURCE'
      bool test() {
        if x > 100 {
          true
        } else {
          false
        }
      }
    SOURCE
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(ast).to eq(
      test_fun([
                 conditional: {
                   keyword_if: 'if',
                   condition: {
                     comparison: {
                       left: { var_ref: 'x' },
                       operator: '>',
                       right: { int_term: '100' }
                     }
                   },
                   then: [{ bool_term: 'true' }],
                   keyword_else: 'else',
                   else: [{ bool_term: 'false' }]
                 }
               ])
    )
  end

  it 'parses an if-else-if chain' do
    source = <<~'SOURCE'
      bool test() {
        if x > 100 {
           100
        } else if x > 10 {
           10
        } else {
           1
        }
      }
    SOURCE
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(ast).to eq(
      test_fun([
                 {
                   conditional: [
                     {
                       keyword_if: 'if',
                       condition: {
                         comparison: {
                           left: { var_ref: 'x' },
                           operator: '>',
                           right: { int_term: '100' }
                         }
                       },
                       then: [
                         { int_term: '100' }
                       ]
                     },
                     {
                       keyword_elseif: 'else if',
                       condition: {
                         comparison: {
                           left: { var_ref: 'x' },
                           operator: '>',
                           right: { int_term: '10' }
                         }
                       },
                       then: [
                         { int_term: '10' }
                       ]
                     },
                     {
                       keyword_else: 'else',
                       else: [
                         { int_term: '1' }
                       ]
                     }
                   ]
                 }
               ])
    )
    program = stringify(Wrapsher::Transformer.new.transform(ast)).flatten
    expect(program).to eq(
      test_fun([
                 {
                   conditional: {
                     keyword_if: 'if',
                     condition: {
                       fun_call: {
                         name: 'gt',
                         fun_args: [{ var_ref: 'x' }, { int_term: '100' }]
                       }
                     },
                     then: [{ int_term: '100' }],
                     keyword_else: 'else if',
                     else: {
                       conditional: {
                         keyword_if: 'else if',
                         keyword_elseif: 'else if',
                         condition: {
                           fun_call: {
                             name: 'gt',
                             fun_args: [{ var_ref: 'x' }, { int_term: '10' }]
                           }
                         },
                         then: [{ int_term: '10' }],
                         keyword_else: 'else',
                         else: [
                           { int_term: '1' }
                         ]
                       }
                     }
                   }
                 }
               ])
    )
  end

  it 'parses some wrapsher' do
    source = <<~SOURCE
      module ex
      meta author 'dev@mermaidpurse.org'
      use version 0
      type vector list
    SOURCE
    parser = Wrapsher::Parser.new
    ast = stringify(parser.parsetext(source)).flatten
    expect(ast).to eq([
                        { module: 'ex' },
                        { meta: { meta_field: 'author', meta_data: { single_quoted: 'dev@mermaidpurse.org' } } },
                        { use_version: '0' },
                        { type: { name: 'vector', store_type: 'list' } }
                      ])
  end
end
# rubocop:enable Metrics/BlockLength

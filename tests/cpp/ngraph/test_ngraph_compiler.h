// ----------------------------------------------------------------------------
// Copyright 2017 Nervana Systems Inc.
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// ----------------------------------------------------------------------------

#include <nnvm/graph.h>
#include "ngraph_compiler.h"
#include "test_util.h"

namespace ngraph_bridge{

class NGRAPH_COMPILER : public ::testing::Test {
 protected:
  nnvm::NodeEntry createNode(std::string name, std::string op = "") {
    nnvm::NodeAttrs attr;
    auto node = nnvm::Node::Create();
    attr.name = name;
    if (op != "") attr.op = nnvm::Op::Get(op);
    node->attrs = attr;
    nodes_[name] = node;
    return nnvm::NodeEntry{node, 0, 0};
  }
  

  virtual void SetUp() {
    auto A = createNode("A");
    auto B = createNode("B");
    auto C = createNode("C");
    auto D = createNode("D");
    auto add1 = createNode("add1", "_add");
    auto mul = createNode("mul", "_mul");
    auto add2 = createNode("add2", "_add");
    auto relu = createNode("relu", "relu");

    add1.node->inputs.push_back(A);
    add1.node->inputs.push_back(B);

    mul.node->inputs.push_back(add1);
    mul.node->inputs.push_back(C);

    add2.node->inputs.push_back(mul);
    add2.node->inputs.push_back(D);

    relu.node->inputs.push_back(add2);

    nnvm_graph.outputs.push_back(relu);

    nnvm::TShape shape{2, 2};
    std::unordered_map<std::string, int> dtypes;
    std::unordered_map<std::string, nnvm::TShape> shapes;

    for (auto n : {A, B, C, D}) inputs.push_back(n.node);

    for (auto n : {"A", "B", "C", "D"}) {
      dtypes[n] = 0;
      shapes[n] = shape;
    }
    feed_dict[A] = mxnet::NDArray(shape, mxnet::Context());
    bindarg = std::make_shared<ngraph_bridge::SimpleBindArg>(4, shapes, dtypes);
  };

  virtual void TearDown(){};

  nnvm::Graph nnvm_graph;
  std::shared_ptr<ngraph_bridge::SimpleBindArg> bindarg;

  NDArrayMap feed_dict;
  NNVMNodeVec inputs;
  std::unordered_map<std::string, nnvm::NodePtr> nodes_;
};

class testCompiler : public Compiler{
 public:
  using Compiler::CheckInNgraph;
  using Compiler::DeepCopy;
  using Compiler::CopyNodes;
  using Compiler::MakeCopiedFeedDict;
  using Compiler::MakeCopiedInputs;
  using Compiler::Infer;
  using Compiler::node_map_;
  using Compiler::graph_;
  using Compiler::ngraph_;
  using Compiler::compiler_;
  testCompiler(const nnvm::Graph& graph, const NDArrayMap& feed_dict,
               const NNVMNodeVec& inputs, const BindArgBase& bindarg)
      : Compiler(graph, feed_dict, inputs, bindarg){};
};

}
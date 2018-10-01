/*
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */

/*!
 * Copyright (c) 2018 Intel Corporation
 * \file ngraph.cc
 * \brief ngraph subgraph property for mxnet
*/

#ifndef MXNET_OPERATOR_CONTRIB_NGRAPH_INL_H_
#define MXNET_OPERATOR_CONTRIB_NGRAPH_INL_H_

#if MXNET_USE_NGRAPH
#include <ngraph_compiler.h>
#include <ngraph_imperative.h>
#include <ngraph_nnvm_ops.h>

#include <vector>

#include "../subgraph/common.h"
#include "../subgraph/subgraph_property.h"

namespace mxnet {
namespace op {

class SgNgraphSelector : public SubgraphSelector {
 public:
  explicit SgNgraphSelector(ngraph_bridge::Compiler *compiler)
      : compiler_(compiler), valid(compiler_->get_node_map().size() > 0) {}

  bool Select(const nnvm::Node &n) override { return is_node_selected(n); }

  bool SelectInput(const nnvm::Node &n, const nnvm::Node &new_node) override {
    return is_node_selected(n, &new_node);
  }

  bool SelectOutput(const nnvm::Node &n, const nnvm::Node &new_node) override {
    return is_node_selected(n, &new_node);
  }
  std::vector<nnvm::Node *> Filter(
      const std::vector<nnvm::Node *> &candidates) {
    if (candidates.size() == 1 && candidates[0]->inputs.size() == 0) {
      return std::vector<nnvm::Node *>();
    } else {
      return candidates;
    }
  }

 private:
  ngraph_bridge::Compiler *compiler_;
  const bool valid;
  ngraph_bridge::NodePtr get_node(const nnvm::Node *n) {
    if (n) {
      auto &entry_map = compiler_->get_ngraph().entry_map_;
      ngraph_bridge::MapEntry tmp{compiler_->get_node_map().at(n).get(), 0};
      if (entry_map.count(tmp)) {
        return entry_map[tmp];
      }
    }
    return nullptr;
  }
  bool is_node_selected(const nnvm::Node &n, const nnvm::Node *next = nullptr) {
    bool selected = false;
    if (!valid) return selected;

    auto nn = get_node(&n);
    auto nnext = get_node(next);

    selected = nn && nn->in_ngraph_;
    if (next) {
      selected =
          selected && nnext->in_ngraph_ && nn->subgraph_ == nnext->subgraph_;
    }
    return selected;
  }
};

class SgNgraphProperty : public SubgraphProperty {
 public:
  static SubgraphPropertyPtr Create() {
    return std::make_shared<SgNgraphProperty>();
  }

  bool NeedGraphAttrs() const override { return true; }
  nnvm::NodePtr CreateSubgraphNode(
      const nnvm::Symbol &sym, const int subgraph_id = 0) const override {
    nnvm::NodePtr n = nnvm::Node::Create();
    n->attrs.op = Op::Get("_ngraph_subgraph_op");
    n->attrs.name = "_ngraph_subgraph_op" + std::to_string(subgraph_id);
    n->attrs.subgraphs.push_back(std::make_shared<nnvm::Symbol>(sym));
    return n;
  }

  nnvm::NodePtr CreateSubgraphNode(
      const nnvm::Graph &sg, const int subgraph_id = 0) const override {
    nnvm::Symbol sym;
    sym.outputs = sg.outputs;
    auto n = CreateSubgraphNode(sym, subgraph_id);

    auto compiler = std::make_shared<ngraph_bridge::Compiler>(sg);
    compiler->GetNgraph();
    n->attrs.parsed = compiler;
    return n;
  }

  SubgraphSelectorPtr CreateSubgraphSelector() const override {
    if (!compiler_) {
      auto &orig_graph = GetAttr<nnvm::Graph>("graph");
      compiler_ = std::make_shared<ngraph_bridge::Compiler>(orig_graph, true);
    }
    return std::make_shared<SgNgraphSelector>(compiler_.get());
  }

 private:
  mutable std::shared_ptr<ngraph_bridge::Compiler> compiler_;
};

}  // namespace op
}  // namespace mxnet

#endif  // MXNET_USE_NGRAPH

#endif  // MXNET_OPERATOR_CONTRIB_NGRAPH_INL_H_

/**
 * Copyright (c) 2025 Bytedance Ltd. and/or its affiliates
 * SPDX-License-Identifier: MIT
 */

import { INodeExecutorFactory } from '@flowgram.ai/runtime-interface';

import { StartExecutor } from './start';
import { LoopExecutor } from './loop';
import { LLMExecutor } from './llm';
import { EndExecutor } from './end';
import { BlockEndExecutor, BlockStartExecutor } from './empty';
import { ConditionExecutor } from './condition';

export const WorkflowRuntimeNodeExecutors: INodeExecutorFactory[] = [
  StartExecutor,
  EndExecutor,
  LLMExecutor,
  ConditionExecutor,
  LoopExecutor,
  BlockStartExecutor,
  BlockEndExecutor,
];

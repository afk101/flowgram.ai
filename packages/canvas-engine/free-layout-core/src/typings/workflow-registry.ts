/**
 * Copyright (c) 2025 Bytedance Ltd. and/or its affiliates
 * SPDX-License-Identifier: MIT
 */

import type { FormMeta } from '@q/flowgram.ai.node';
import type { FormMetaOrFormMetaGenerator } from '@q/flowgram.ai.form-core';
import type { FlowNodeRegistry } from '@q/flowgram.ai.document';

import type { WorkflowNodeEntity } from '../entities';
import type { WorkflowNodeMeta } from './workflow-node';

/**
 * 节点表单引擎配置
 */
export type WorkflowNodeFormMeta = FormMetaOrFormMetaGenerator | FormMeta;

/**
 * 节点注册
 */
export interface WorkflowNodeRegistry extends FlowNodeRegistry<WorkflowNodeMeta> {
  formMeta?: WorkflowNodeFormMeta;
}

export interface WorkflowNodeRenderProps {
  node: WorkflowNodeEntity;
}

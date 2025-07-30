/**
 * Copyright (c) 2025 Bytedance Ltd. and/or its affiliates
 * SPDX-License-Identifier: MIT
 */

import { FlowOperation, FlowOperationBaseService } from '@q/flowgram.ai.document';
import { PluginContext } from '@q/flowgram.ai.core';
import { OperationMeta } from '@q/flowgram.ai.history';

import { FixedHistoryOperationService } from '../services';

export const baseOperationMeta: Pick<OperationMeta, 'apply'> = {
  apply: (operation, ctx: PluginContext) => {
    const fixedHistoryOperationService = ctx.get(
      FlowOperationBaseService,
    ) as FixedHistoryOperationService;

    return fixedHistoryOperationService.originApply(operation as FlowOperation);
  },
};

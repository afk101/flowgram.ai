/**
 * Copyright (c) 2025 Bytedance Ltd. and/or its affiliates
 * SPDX-License-Identifier: MIT
 */

import { ContainerModule } from 'inversify';
import { FlowRendererContribution } from '@q/flowgram.ai.renderer';
import { FlowDocumentContribution } from '@q/flowgram.ai.document';
import { PlaygroundContribution } from '@q/flowgram.ai.core';
import { bindContributions } from '@q/flowgram.ai.utils';

import { FlowRegisters } from './flow-registers';

export const FixedLayoutContainerModule = new ContainerModule(bind => {
  bindContributions(bind, FlowRegisters, [
    FlowDocumentContribution,
    FlowRendererContribution,
    PlaygroundContribution,
  ]);
});

/**
 * Copyright (c) 2025 Bytedance Ltd. and/or its affiliates
 * SPDX-License-Identifier: MIT
 */

import React from 'react';

import { type NodeRenderReturnType } from '@q/flowgram.ai.fixed-layout-editor';

export const NodeRenderContext = React.createContext<NodeRenderReturnType>({} as any);

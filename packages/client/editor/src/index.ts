/**
 * Copyright (c) 2025 Bytedance Ltd. and/or its affiliates
 * SPDX-License-Identifier: MIT
 */

import 'reflect-metadata';
import { FormModelV2 } from '@q/flowgram.ai.node';

/* 核心 模块导出 */
export * from '@q/flowgram.ai.utils';
export * from '@q/flowgram.ai.core';
export * from '@q/flowgram.ai.document';
export * from '@q/flowgram.ai.renderer';
export * from '@q/flowgram.ai.variable-plugin';
export * from '@q/flowgram.ai.shortcuts-plugin';
export * from '@q/flowgram.ai.node-core-plugin';
export * from '@q/flowgram.ai.i18n-plugin';
export {
  type interfaces,
  injectable,
  postConstruct,
  named,
  Container,
  ContainerModule,
  AsyncContainerModule,
  inject,
  multiInject,
} from 'inversify';

export { FlowNodeFormData, NodeRender, type NodeRenderProps } from '@q/flowgram.ai.form-core';

export type {
  FormState,
  FieldState,
  FieldArrayRenderProps,
  FieldRenderProps,
  FormRenderProps,
  Validate,
  FormControl,
  FieldName,
  FieldError,
  FieldWarning,
  IField,
  IFieldArray,
  IForm,
  Errors,
  Warnings,
} from '@q/flowgram.ai.form';

export {
  Form,
  Field,
  FieldArray,
  useForm,
  useField,
  useCurrentField,
  useCurrentFieldState,
  useFieldValidate,
  useWatch,
  ValidateTrigger,
  FeedbackLevel,
} from '@q/flowgram.ai.form';
export * from '@q/flowgram.ai.node';
export { FormModelV2 as FormModel };

/**
 * 固定布局模块导出
 */
export * from './preset';
export * from './components';
export * from './hooks';
export * from './clients';

/**
 * Plugin 导出
 */

export * from '@q/flowgram.ai.node-variable-plugin';

export { createPlaygroundReactPreset } from '@q/flowgram.ai.playground-react';

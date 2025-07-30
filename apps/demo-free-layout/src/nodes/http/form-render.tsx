/**
 * Copyright (c) 2025 Bytedance Ltd. and/or its affiliates
 * SPDX-License-Identifier: MIT
 */

import { FormRenderProps } from '@flowgram.ai/free-layout-editor';
import { Divider } from '@douyinfe/semi-ui';

import { FormHeader, FormContent, FormOutputs } from '../../form-components';
import { HTTPNodeJSON } from './types';
import { Timeout } from './components/timeout';
import { Body } from './components/body';
import { Api } from './components/api';

export const FormRender = ({ form }: FormRenderProps<HTTPNodeJSON>) => (
  <>
    <FormHeader />
    <FormContent>
      <Api />
      <Divider />
      <Body />
      <Divider />
      <Timeout />
      <FormOutputs />
    </FormContent>
  </>
);

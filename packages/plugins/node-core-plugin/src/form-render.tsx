/**
 * Copyright (c) 2025 Bytedance Ltd. and/or its affiliates
 * SPDX-License-Identifier: MIT
 */

import { useEffect } from 'react';

import { FlowNodeFormData, FormModel } from '@q/flowgram.ai.form-core';
import { FlowNodeEntity } from '@q/flowgram.ai.document';
import { PlaygroundContext, useRefresh } from '@q/flowgram.ai.core';

interface FormRenderProps {
  node: FlowNodeEntity;
  playgroundContext?: PlaygroundContext;
}

function getFormModelFromNode(node: FlowNodeEntity) {
  return node.getData(FlowNodeFormData)?.getFormModel<FormModel>();
}

export function FormRender({ node }: FormRenderProps): any {
  const refresh = useRefresh();
  const formModel = getFormModelFromNode(node);

  useEffect(() => {
    const disposable = formModel?.onInitialized(() => {
      refresh();
    });
    return () => {
      disposable.dispose();
    };
  }, [formModel]);

  return formModel?.initialized ? formModel.render() : null;
}

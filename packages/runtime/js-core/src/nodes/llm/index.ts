/**
 * Copyright (c) 2025 Bytedance Ltd. and/or its affiliates
 * SPDX-License-Identifier: MIT
 */

import { isNil } from 'lodash-es';
import { ChatOpenAI } from '@langchain/openai';
import { SystemMessage, HumanMessage, BaseMessageLike } from '@langchain/core/messages';
import {
  ExecutionContext,
  ExecutionResult,
  FlowGramNode,
  INodeExecutor,
} from '@flowgram.ai/runtime-interface';

import { APIValidator } from './api-validator';

export interface LLMExecutorInputs {
  modelName: string;
  apiKey: string;
  apiHost: string;
  temperature: number;
  systemPrompt?: string;
  prompt: string;
}

export class LLMExecutor implements INodeExecutor {
  public type = FlowGramNode.LLM;

  public async execute(context: ExecutionContext): Promise<ExecutionResult> {
    const inputs = context.inputs as LLMExecutorInputs;
    await this.checkInputs(inputs);

    const { modelName, temperature, apiKey, apiHost, systemPrompt, prompt } = inputs;

    const model = new ChatOpenAI({
      modelName,
      temperature,
      apiKey,
      configuration: {
        baseURL: apiHost,
      },
    });

    const messages: BaseMessageLike[] = [];

    if (systemPrompt) {
      messages.push(new SystemMessage(systemPrompt));
    }
    messages.push(new HumanMessage(prompt));

    let apiMessage;
    try {
      apiMessage = await model.invoke(messages);
    } catch (error) {
      // 调用 LLM API 失败
      const errorMessage = (error as Error)?.message;
      if (errorMessage === 'Connection error.') {
        throw new Error(`Network error: unreachable api "${apiHost}"`);
      }
      throw error;
    }

    const result = apiMessage.content;
    return {
      outputs: {
        result,
      },
    };
  }

  protected async checkInputs(inputs: LLMExecutorInputs) {
    const { modelName, temperature, apiKey, apiHost, prompt } = inputs;
    const missingInputs = [];

    if (!modelName) missingInputs.push('modelName');
    if (isNil(temperature)) missingInputs.push('temperature');
    if (!apiKey) missingInputs.push('apiKey');
    if (!apiHost) missingInputs.push('apiHost');
    if (!prompt) missingInputs.push('prompt');

    if (missingInputs.length > 0) {
      throw new Error(`LLM node missing required inputs: "${missingInputs.join('", "')}"`);
    }

    // Validate apiHost format before checking existence
    if (!APIValidator.isValidFormat(apiHost)) {
      throw new Error(`Invalid API host format - ${apiHost}`);
    }

    const apiHostExists = await APIValidator.isExist(apiHost);
    if (!apiHostExists) {
      throw new Error(`Unreachable API host - ${apiHost}`);
    }
  }
}

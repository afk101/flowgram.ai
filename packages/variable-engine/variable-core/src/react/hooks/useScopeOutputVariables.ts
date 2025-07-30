/**
 * Copyright (c) 2025 Bytedance Ltd. and/or its affiliates
 * SPDX-License-Identifier: MIT
 */

import { useCallback, useEffect, useMemo, useState } from 'react';

import { DisposableCollection } from '@flowgram.ai/utils';
import { useService } from '@flowgram.ai/core';

import { useCurrentScope } from '../context';
import { VariableEngine } from '../../variable-engine';
import { Scope } from '../../scope';
import {
  DisposeASTAction,
  GlobalEventActionType,
  NewASTAction,
  UpdateASTAction,
} from '../../ast/types';

export function useScopeOutputVariables(scopeFromParam?: Scope | Scope[]) {
  const currentScope = useCurrentScope();
  const variableEngine = useService(VariableEngine);

  const [refreshKey, setRefreshKey] = useState(0);

  const scopes = useMemo(
    () => {
      if (!scopeFromParam) {
        return [currentScope];
      }
      if (Array.isArray(scopeFromParam)) {
        return scopeFromParam;
      }
      return [scopeFromParam];
    },
    Array.isArray(scopeFromParam) ? scopeFromParam : [scopeFromParam]
  );

  useEffect(() => {
    setRefreshKey((_key) => _key + 1);

    const refreshWhenInScopes = useCallback((action: GlobalEventActionType) => {
      if (scopes.includes(action.ast?.scope!)) {
        setRefreshKey((_key) => _key + 1);
      }
    }, []);

    const disposable = new DisposableCollection();

    disposable.pushAll([
      variableEngine.onGlobalEvent<DisposeASTAction>('DisposeAST', refreshWhenInScopes),
      variableEngine.onGlobalEvent<NewASTAction>('NewAST', refreshWhenInScopes),
      variableEngine.onGlobalEvent<UpdateASTAction>('UpdateAST', refreshWhenInScopes),
    ]);

    return () => disposable.dispose();
  }, [scopes]);

  const variables = useMemo(
    () => scopes.map((scope) => scope.output.variables).flat(),
    [scopes, refreshKey]
  );

  return variables;
}

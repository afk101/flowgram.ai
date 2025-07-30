/**
 * Copyright (c) 2025 Bytedance Ltd. and/or its affiliates
 * SPDX-License-Identifier: MIT
 */

/* eslint-disable @typescript-eslint/no-non-null-assertion -- no need */
import { throttle } from 'lodash';
import { inject, injectable } from 'inversify';
import {
  type PositionSchema,
  Rectangle,
  type Disposable,
  DisposableCollection,
  Emitter,
  type IPoint,
} from '@flowgram.ai/utils';
import {
  type NodesDragEvent,
  WorkflowDocument,
  WorkflowDragService,
  WorkflowLinesManager,
  type WorkflowNodeEntity,
  WorkflowNodeMeta,
  WorkflowOperationBaseService,
  WorkflowSelectService,
} from '@flowgram.ai/free-layout-core';
import { HistoryService } from '@flowgram.ai/free-history-plugin';
import { FlowNodeTransformData, FlowNodeRenderData, FlowNodeBaseType } from '@flowgram.ai/document';
import { PlaygroundConfigEntity, TransformData } from '@flowgram.ai/core';

import type { NodeIntoContainerEvent, NodeIntoContainerState } from './type';
import { NodeIntoContainerType } from './constant';

@injectable()
export class NodeIntoContainerService {
  public state: NodeIntoContainerState;

  @inject(WorkflowDragService)
  private dragService: WorkflowDragService;

  @inject(WorkflowDocument)
  private document: WorkflowDocument;

  @inject(PlaygroundConfigEntity)
  private playgroundConfig: PlaygroundConfigEntity;

  @inject(WorkflowOperationBaseService)
  private operationService: WorkflowOperationBaseService;

  @inject(WorkflowLinesManager)
  private linesManager: WorkflowLinesManager;

  @inject(HistoryService) private historyService: HistoryService;

  @inject(WorkflowSelectService) private selectService: WorkflowSelectService;

  private emitter = new Emitter<NodeIntoContainerEvent>();

  private toDispose = new DisposableCollection();

  public readonly on = this.emitter.event;

  public init(): void {
    this.initState();
    this.toDispose.push(this.emitter);
  }

  public ready(): void {
    this.toDispose.push(this.listenDragToContainer());
  }

  public dispose(): void {
    this.initState();
    this.toDispose.dispose();
  }

  /** 将节点移出容器 */
  public async moveOutContainer(params: { node: WorkflowNodeEntity }): Promise<void> {
    const { node } = params;
    const parentNode = node.parent;
    const containerNode = parentNode?.parent;
    const nodeJSON = this.document.toNodeJSON(node);
    if (
      !parentNode ||
      !containerNode ||
      !this.isContainer(parentNode) ||
      !nodeJSON.meta?.position
    ) {
      return;
    }
    const parentTransform = parentNode.getData<TransformData>(TransformData);
    this.operationService.moveNode(node, {
      parent: containerNode,
    });
    await this.nextFrame();
    parentTransform.fireChange();
    this.operationService.updateNodePosition(node, {
      x: parentTransform.position.x + nodeJSON.meta!.position!.x,
      y: parentTransform.position.y + nodeJSON.meta!.position!.y,
    });
    this.emitter.fire({
      type: NodeIntoContainerType.Out,
      node,
      sourceContainer: parentNode,
      targetContainer: containerNode,
    });
  }

  /** 能否将节点移出容器 */
  public canMoveOutContainer(node: WorkflowNodeEntity): boolean {
    const parentNode = node.parent;
    const containerNode = parentNode?.parent;
    if (!parentNode || !containerNode || !this.isContainer(parentNode)) {
      return false;
    }
    const canDrop = this.dragService.canDropToNode({
      dragNodeType: node.flowNodeType,
      dragNode: node,
      dropNodeType: containerNode?.flowNodeType,
      dropNode: containerNode,
    });
    if (!canDrop.allowDrop) {
      return false;
    }
    return true;
  }

  /** 移除节点所有非法连线 */
  public async clearInvalidLines(params: {
    dragNode?: WorkflowNodeEntity;
    sourceParent?: WorkflowNodeEntity;
  }): Promise<void> {
    const { dragNode, sourceParent } = params;
    if (!dragNode) {
      return;
    }
    if (dragNode.parent === sourceParent) {
      // 容器节点未改变
      return;
    }
    if (
      dragNode.parent?.flowNodeType === FlowNodeBaseType.GROUP ||
      sourceParent?.flowNodeType === FlowNodeBaseType.GROUP
    ) {
      // 移入移出 group 节点无需删除节点
      return;
    }
    await this.removeNodeLines(dragNode);
  }

  /** 移除节点连线 */
  public async removeNodeLines(node: WorkflowNodeEntity): Promise<void> {
    const lines = this.linesManager.getAllLines();
    lines.forEach((line) => {
      if (line.from.id !== node.id && line.to?.id !== node.id) {
        return;
      }
      line.dispose();
    });
    await this.nextFrame();
  }

  /** 初始化状态 */
  private initState(): void {
    this.state = {
      isDraggingNode: false,
      isSkipEvent: false,
      transforms: undefined,
      dragNode: undefined,
      dropNode: undefined,
      sourceParent: undefined,
    };
  }

  /** 监听节点拖拽 */
  private listenDragToContainer(): Disposable {
    const draggingNode = (e: NodesDragEvent) => this.draggingNode(e);
    const throttledDraggingNode = throttle(draggingNode, 200); // 200ms触发一次计算
    return this.dragService.onNodesDrag(async (event) => {
      if (this.selectService.selectedNodes.length !== 1) {
        return;
      }
      if (event.type === 'onDragStart') {
        if (this.state.isSkipEvent) {
          // 拖出容器后重新进入
          this.state.isSkipEvent = false;
          return;
        }
        this.historyService.startTransaction(); // 开始合并历史记录
        this.state.isDraggingNode = true;
        this.state.transforms = this.getContainerTransforms();
        this.state.dragNode = this.selectService.selectedNodes[0];
        this.state.dropNode = undefined;
        this.state.sourceParent = this.state.dragNode?.parent;
        await this.dragOutContainer(event); // 检查是否需拖出容器
      }
      if (event.type === 'onDragging') {
        throttledDraggingNode(event);
      }
      if (event.type === 'onDragEnd') {
        if (this.state.isSkipEvent) {
          // 拖出容器情况下需跳过本次事件
          return;
        }
        throttledDraggingNode.cancel();
        draggingNode(event); // 直接触发一次计算，防止延迟
        await this.dropNodeToContainer(); // 放置节点
        await this.clearInvalidLines({
          dragNode: this.state.dragNode,
          sourceParent: this.state.sourceParent,
        }); // 清除非法线条
        this.setDropNode(undefined);
        this.initState(); // 重置状态
        this.historyService.endTransaction(); // 结束合并历史记录
      }
    });
  }

  /** 监听节点拖拽出容器 */
  private async dragOutContainer(event: NodesDragEvent): Promise<void> {
    const { dragNode } = this.state;
    const activated = event.triggerEvent.metaKey || event.triggerEvent.ctrlKey;
    if (
      !activated || // 必须按住指定按键
      !dragNode || // 必须有一个节点
      !this.canMoveOutContainer(dragNode) // 需要能被移出容器
    ) {
      return;
    }
    this.moveOutContainer({ node: dragNode });
    this.state.isSkipEvent = true;
    event.dragger.stop(event.dragEvent.clientX, event.dragEvent.clientY);
    await this.nextFrame();
    this.dragService.startDragSelectedNodes(event.triggerEvent);
  }

  /** 获取重叠位置 */
  private getCollisionTransform(params: {
    transforms: FlowNodeTransformData[];
    targetRect?: Rectangle;
    targetPoint?: PositionSchema;
    withPadding?: boolean;
  }): FlowNodeTransformData | undefined {
    const { targetRect, targetPoint, transforms, withPadding = false } = params;
    const collisionTransform = transforms.find((transform) => {
      const { bounds, entity } = transform;
      const padding = withPadding ? this.document.layout.getPadding(entity) : { left: 0, right: 0 };
      const transformRect = new Rectangle(
        bounds.x + padding.left + padding.right,
        bounds.y,
        bounds.width,
        bounds.height
      );
      // 检测两个正方形是否相互碰撞
      if (targetRect) {
        return this.isRectIntersects(targetRect, transformRect);
      }
      if (targetPoint) {
        return this.isPointInRect(targetPoint, transformRect);
      }
      return false;
    });
    return collisionTransform;
  }

  /** 设置放置节点高亮 */
  private setDropNode(dropNode?: WorkflowNodeEntity) {
    if (this.state.dropNode === dropNode) {
      return;
    }
    if (this.state.dropNode) {
      // 清除上一个节点高亮
      const renderData = this.state.dropNode.getData(FlowNodeRenderData);
      const renderDom = renderData.node?.children?.[0] as HTMLElement;
      if (renderDom) {
        renderDom.classList.remove('selected');
      }
    }
    this.state.dropNode = dropNode;
    if (!dropNode) {
      return;
    }
    // 设置当前节点高亮
    const renderData = dropNode.getData(FlowNodeRenderData);
    const renderDom = renderData.node?.children?.[0] as HTMLElement;
    if (renderDom) {
      renderDom.classList.add('selected');
    }
  }

  /** 获取容器节点transforms */
  private getContainerTransforms(): FlowNodeTransformData[] {
    return this.document
      .getAllNodes()
      .filter((node) => {
        if (node.originParent) {
          return node.getNodeMeta().selectable && node.originParent.getNodeMeta().selectable;
        }
        return node.getNodeMeta().selectable;
      })
      .filter((node) => this.isContainer(node))
      .sort((a, b) => {
        const aIndex = a.renderData.stackIndex;
        const bIndex = b.renderData.stackIndex;
        //  确保层级高的节点在前面
        return bIndex - aIndex;
      })
      .map((node) => node.transform);
  }

  /** 放置节点到容器 */
  private async dropNodeToContainer(): Promise<void> {
    const { dropNode, dragNode, isDraggingNode } = this.state;
    if (!isDraggingNode || !dragNode || !dropNode) {
      return;
    }
    return await this.moveIntoContainer({
      node: dragNode,
      containerNode: dropNode,
    });
  }

  /** 拖拽节点 */
  private draggingNode(nodeDragEvent: NodesDragEvent): void {
    const { dragNode, isDraggingNode, transforms = [] } = this.state;
    if (!isDraggingNode || !dragNode || !transforms?.length) {
      return this.setDropNode(undefined);
    }
    const mousePos = this.playgroundConfig.getPosFromMouseEvent(nodeDragEvent.dragEvent);
    const availableTransforms = transforms.filter(
      (transform) => transform.entity.id !== dragNode.id
    );
    const collisionTransform = this.getCollisionTransform({
      targetPoint: mousePos,
      transforms: availableTransforms,
    });
    const dropNode = collisionTransform?.entity;
    const canDrop = this.canDropToContainer({
      dragNode,
      dropNode,
    });
    if (!canDrop) {
      return this.setDropNode(undefined);
    }
    return this.setDropNode(dropNode);
  }

  /** 判断能否将节点拖入容器 */
  protected canDropToContainer(params: {
    dragNode: WorkflowNodeEntity;
    dropNode?: WorkflowNodeEntity;
  }): boolean {
    const { dragNode, dropNode } = params;
    const isDropContainer = dropNode?.getNodeMeta<WorkflowNodeMeta>().isContainer;
    if (!dropNode || !isDropContainer || this.isParent(dragNode, dropNode)) {
      return false;
    }
    if (
      dragNode.flowNodeType === FlowNodeBaseType.GROUP &&
      dropNode.flowNodeType !== FlowNodeBaseType.GROUP
    ) {
      // 禁止将 group 节点拖入非 group 节点（由于目前不支持多节点拖入容器，无法计算有效线条，因此进行屏蔽）
      return false;
    }
    const canDrop = this.dragService.canDropToNode({
      dragNodeType: dragNode.flowNodeType,
      dropNodeType: dropNode?.flowNodeType,
      dragNode,
      dropNode,
    });
    if (!canDrop.allowDrop) {
      return false;
    }
    return true;
  }

  /** 判断一个节点是否为另一个节点的父节点(向上查找直到根节点) */
  private isParent(node: WorkflowNodeEntity, parent: WorkflowNodeEntity): boolean {
    let current = node.parent;
    while (current) {
      if (current.id === parent.id) {
        return true;
      }
      current = current.parent;
    }
    return false;
  }

  /** 将节点移入容器 */
  private async moveIntoContainer(params: {
    node: WorkflowNodeEntity;
    containerNode: WorkflowNodeEntity;
  }): Promise<void> {
    const { node, containerNode } = params;
    const parentNode = node.parent;

    this.operationService.moveNode(node, {
      parent: containerNode,
    });

    this.operationService.updateNodePosition(node, this.adjustSubNodePosition(node, containerNode));

    await this.nextFrame();

    this.emitter.fire({
      type: NodeIntoContainerType.In,
      node,
      sourceContainer: parentNode,
      targetContainer: containerNode,
    });
  }

  /**
   * 如果存在容器节点，且传入鼠标坐标，需要用容器的坐标减去传入的鼠标坐标
   */
  private adjustSubNodePosition(
    targetNode: WorkflowNodeEntity,
    containerNode: WorkflowNodeEntity
  ): IPoint {
    if (containerNode.flowNodeType === FlowNodeBaseType.ROOT) {
      return targetNode.transform.position;
    }
    const nodeWorldTransform = targetNode.transform.transform.worldTransform;
    const containerWorldTransform = containerNode.transform.transform.worldTransform;
    const nodePosition = {
      x: nodeWorldTransform.tx,
      y: nodeWorldTransform.ty,
    };
    const isParentEmpty = !containerNode.children || containerNode.children.length === 0;
    const containerPadding = this.document.layout.getPadding(containerNode);
    if (isParentEmpty) {
      // 确保空容器节点不偏移
      return {
        x: 0,
        y: containerPadding.top,
      };
    } else {
      return {
        x: nodePosition.x - containerWorldTransform.tx,
        y: nodePosition.y - containerWorldTransform.ty,
      };
    }
  }

  private isContainer(node?: WorkflowNodeEntity): boolean {
    return node?.getNodeMeta<WorkflowNodeMeta>().isContainer ?? false;
  }

  /** 判断点是否在矩形内 */
  private isPointInRect(point: PositionSchema, rect: Rectangle): boolean {
    return (
      point.x >= rect.left && point.x <= rect.right && point.y >= rect.top && point.y <= rect.bottom
    );
  }

  /** 判断两个矩形是否相交 */
  private isRectIntersects(rectA: Rectangle, rectB: Rectangle): boolean {
    // 检查水平方向是否有重叠
    const hasHorizontalOverlap = rectA.right > rectB.left && rectA.left < rectB.right;
    // 检查垂直方向是否有重叠
    const hasVerticalOverlap = rectA.bottom > rectB.top && rectA.top < rectB.bottom;
    // 只有当水平和垂直方向都有重叠时,两个矩形才相交
    return hasHorizontalOverlap && hasVerticalOverlap;
  }

  private async nextFrame(): Promise<void> {
    await new Promise((resolve) => requestAnimationFrame(resolve));
  }
}

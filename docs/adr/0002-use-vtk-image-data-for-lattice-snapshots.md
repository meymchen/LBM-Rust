# 使用 VTK ImageData 交换格子场快照

首版 VTK 交换只承诺均匀笛卡尔格子，并将每个 LBM 格点映射为 VTK point，以 x 最快、再 y、最后 z 的顺序写入 XML ImageData（`.vti`）。二维场表示为单层三维数据，速度补零为三分量；格式无关的借用型二维场快照经过尺寸和数值验证后，才在外围转换成 vtkio 类型。稳定字段名为 `density`、`velocity` 和 `boundary_kind`；区域编号 `0` 至 `4` 依次表示 fluid、wall、inlet、outlet 和 solid，离散分布函数只作为显式调试输出。这个选择牺牲了对非均匀和非结构网格的预先通用化，以换取清晰的格点语义、更小的文件和可直接验证的空间布局。

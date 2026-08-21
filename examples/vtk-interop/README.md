# VTK／ParaView 互操作原型

这个示例生成一个 `4 × 3` 的非对称合成场，共有两个物理时间点。它用于发现数组转置、速度分量错误、区域编码漂移和时间清单排序问题，不用于验证 CFD 求解结果。

运行纯 Rust 检查：

```sh
make vtk-smoke
```

运行 ParaView 6.1 后处理检查：

```sh
make paraview-smoke
```

后一个命令会生成速度大小场、流线和中心线剖面 CSV。输出保存在 `build/`，不进入版本控制。

## 场契约

场快照使用 VTK XML ImageData（`.vti`）。每个 LBM 格点对应一个 VTK point，数组按 x 最快、再 y 的顺序排列。二维速度写成三分量向量，z 分量为零。

稳定字段名如下：

- `density`：格点密度；
- `velocity`：三分量格点速度；
- `boundary_kind`：区域标记，`0` 至 `4` 分别表示 fluid、wall、inlet、outlet 和 solid。

版本化的 `fixtures/reference` 使用 ASCII VTK，便于审阅和 diff。生产写入接口使用 zlib 压缩的 binary VTK XML。`.vti.series` 中的文件名记录迭代步，`time` 单独记录物理时间。`run.toml` 保存单位约定、尺寸、字段和再生成命令。

当前 `Cargo.lock` 固定 vtkio 0.7.0-rc2，因为 0.6.3 没有公开的压缩 XML 写入接口。`lbm-vtk` 不向调用方暴露 vtkio 类型；0.7 正式版发布后，应先通过 round-trip 和 ParaView smoke test，再更新锁定版本。

维护者可以显式更新这些资产：

```sh
make regenerate
make check-generated
```

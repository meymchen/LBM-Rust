"""Exercise the reproducible ParaView pipelines for the VTK interop fixture."""

from pathlib import Path
import sys

from paraview.simple import (  # type: ignore[import-not-found]
    Calculator,
    OpenDataFile,
    PlotOverLine,
    SaveData,
    StreamTracer,
    UpdatePipeline,
)


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: pvpython vtk-interop.py INPUT_DIRECTORY OUTPUT_DIRECTORY")

    input_directory = Path(sys.argv[1]).resolve()
    output_directory = Path(sys.argv[2]).resolve()
    output_directory.mkdir(parents=True, exist_ok=False)

    source = OpenDataFile(str(input_directory / "interop.vti.series"))
    if source is None:
        raise RuntimeError("ParaView could not open the VTK time series")

    physical_time = 0.35
    UpdatePipeline(time=physical_time, proxy=source)

    speed = Calculator(registrationName="velocity magnitude", Input=source)
    speed.ResultArrayName = "speed"
    speed.Function = "mag(velocity)"
    UpdatePipeline(time=physical_time, proxy=speed)
    SaveData(
        str(output_directory / "speed.vti"),
        proxy=speed,
        PointDataArrays=["density", "velocity", "boundary_kind", "speed"],
    )

    streamlines = StreamTracer(
        registrationName="velocity streamlines",
        Input=speed,
        SeedType="Line",
    )
    streamlines.Vectors = ["POINTS", "velocity"]
    streamlines.SeedType.Point1 = [0.0, 0.25, 0.0]
    streamlines.SeedType.Point2 = [0.0, 1.75, 0.0]
    streamlines.SeedType.Resolution = 4
    UpdatePipeline(time=physical_time, proxy=streamlines)
    SaveData(str(output_directory / "streamlines.vtp"), proxy=streamlines)

    profile = PlotOverLine(registrationName="centerline profile", Input=speed)
    profile.Point1 = [0.0, 1.0, 0.0]
    profile.Point2 = [3.0, 1.0, 0.0]
    profile.Resolution = 3
    UpdatePipeline(time=physical_time, proxy=profile)
    SaveData(
        str(output_directory / "centerline.csv"),
        proxy=profile,
        PointDataArrays=["density", "velocity", "boundary_kind", "speed"],
    )


if __name__ == "__main__":
    main()

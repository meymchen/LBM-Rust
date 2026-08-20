//! 为文档生成确定性的 D2Q9 平衡分布数据与数据图。

use std::{
    env, fs,
    io::{self, Write},
    path::{Path, PathBuf},
};

use lbm_core::{D2Q9, equilibrium};

fn main() -> io::Result<()> {
    let output_directory = env::args_os()
        .nth(1)
        .map_or_else(|| PathBuf::from("book/assets/generated"), PathBuf::from);
    fs::create_dir_all(&output_directory)?;

    let density = 1.0;
    let velocity = [0.08, 0.02];
    let distributions = equilibrium(density, velocity);

    write_csv(
        &output_directory.join("d2q9-equilibrium.csv"),
        &distributions,
    )?;
    write_svg(
        &output_directory.join("d2q9-equilibrium.svg"),
        density,
        velocity,
        &distributions,
    )
}

fn write_csv(path: &Path, distributions: &[f64; D2Q9::Q]) -> io::Result<()> {
    let mut output = io::BufWriter::new(fs::File::create(path)?);

    writeln!(output, "direction,cx,cy,weight,equilibrium")?;
    for (index, ((velocity, weight), distribution)) in D2Q9::VELOCITIES
        .iter()
        .zip(D2Q9::WEIGHTS)
        .zip(distributions)
        .enumerate()
    {
        writeln!(
            output,
            "{index},{},{},{weight:.12},{population:.12}",
            velocity[0],
            velocity[1],
            population = distribution,
        )?;
    }

    Ok(())
}

// Keep the complete SVG scene together so axes, series, legends, and labels can be audited as one
// deterministic artifact.
#[allow(clippy::too_many_lines)]
fn write_svg(
    path: &Path,
    density: f64,
    velocity: [f64; 2],
    distributions: &[f64; D2Q9::Q],
) -> io::Result<()> {
    const WIDTH: f64 = 920.0;
    const HEIGHT: f64 = 440.0;
    const TOP: f64 = 58.0;
    const PLOT_HEIGHT: f64 = 292.0;
    const PLOT_WIDTH: f64 = 340.0;
    const LEFT_A: f64 = 72.0;
    const LEFT_B: f64 = 522.0;
    const STEP: f64 = PLOT_WIDTH / 8.0;
    const FONT: &str = "Noto Serif CJK SC, Noto Serif, serif";

    fn map_y(value: f64, minimum: f64, maximum: f64) -> f64 {
        TOP + PLOT_HEIGHT * (1.0 - (value - minimum) / (maximum - minimum))
    }

    let normalized = distributions.map(|distribution| distribution / density);
    let deviations: [f64; D2Q9::Q] =
        std::array::from_fn(|index| normalized[index] - D2Q9::WEIGHTS[index]);
    let mut x_a = [0.0; D2Q9::Q];
    let mut x_b = [0.0; D2Q9::Q];
    let mut next_a = LEFT_A;
    let mut next_b = LEFT_B;
    for (left, right) in x_a.iter_mut().zip(&mut x_b) {
        *left = next_a;
        *right = next_b;
        next_a += STEP;
        next_b += STEP;
    }

    let mut output = io::BufWriter::new(fs::File::create(path)?);
    writeln!(
        output,
        r#"<svg xmlns="http://www.w3.org/2000/svg" width="{WIDTH}" height="{HEIGHT}" viewBox="0 0 {WIDTH} {HEIGHT}">"#,
    )?;
    writeln!(output, "  <title id=\"title\">D2Q9 平衡分布</title>")?;
    writeln!(
        output,
        "  <desc id=\"description\">密度 {density:.2}，宏观速度 ({:.2}, {:.2}) 时的 D2Q9 平衡分布。左图与静止权重比较，右图显示二者的差。</desc>",
        velocity[0], velocity[1]
    )?;
    writeln!(
        output,
        "  <rect width=\"100%\" height=\"100%\" fill=\"#ffffff\"/>"
    )?;

    writeln!(
        output,
        "  <text x=\"{LEFT_A}\" y=\"25\" font-family=\"{FONT}\" font-size=\"17\" font-weight=\"600\" fill=\"#171d24\">(a) 平衡分布与静止权重</text>"
    )?;
    writeln!(
        output,
        "  <text x=\"{LEFT_B}\" y=\"25\" font-family=\"{FONT}\" font-size=\"17\" font-weight=\"600\" fill=\"#171d24\">(b) 相对静止权重的偏差</text>"
    )?;

    for tick in 0..=5 {
        let value = f64::from(tick) / 10.0;
        let y = map_y(value, 0.0, 0.5);
        writeln!(
            output,
            "  <line x1=\"{LEFT_A:.1}\" y1=\"{y:.1}\" x2=\"{:.1}\" y2=\"{y:.1}\" stroke=\"#d8dde5\" stroke-width=\"1\"/>",
            LEFT_A + PLOT_WIDTH
        )?;
        writeln!(
            output,
            "  <text x=\"{}\" y=\"{:.1}\" text-anchor=\"end\" font-family=\"{FONT}\" font-size=\"14\" fill=\"#394452\">{value:.1}</text>",
            LEFT_A - 10.0,
            y + 4.0
        )?;
    }

    for tick in -3..=3 {
        let value = f64::from(tick) / 100.0;
        let y = map_y(value, -0.035, 0.035);
        writeln!(
            output,
            "  <line x1=\"{LEFT_B:.1}\" y1=\"{y:.1}\" x2=\"{:.1}\" y2=\"{y:.1}\" stroke=\"{}\" stroke-width=\"{}\"/>",
            LEFT_B + PLOT_WIDTH,
            if tick == 0 { "#59636f" } else { "#d8dde5" },
            if tick == 0 { "1.4" } else { "1" }
        )?;
        writeln!(
            output,
            "  <text x=\"{}\" y=\"{:.1}\" text-anchor=\"end\" font-family=\"{FONT}\" font-size=\"14\" fill=\"#394452\">{value:.2}</text>",
            LEFT_B - 10.0,
            y + 4.0
        )?;
    }

    for (panel_left, positions) in [(LEFT_A, &x_a), (LEFT_B, &x_b)] {
        writeln!(
            output,
            "  <rect x=\"{panel_left:.1}\" y=\"{TOP:.1}\" width=\"{PLOT_WIDTH:.1}\" height=\"{PLOT_HEIGHT:.1}\" fill=\"none\" stroke=\"#171d24\" stroke-width=\"1.4\"/>"
        )?;
        for (index, x) in positions.iter().enumerate() {
            writeln!(
                output,
                "  <line x1=\"{x:.1}\" y1=\"{:.1}\" x2=\"{x:.1}\" y2=\"{:.1}\" stroke=\"#171d24\" stroke-width=\"1\"/>",
                TOP + PLOT_HEIGHT,
                TOP + PLOT_HEIGHT + 6.0
            )?;
            writeln!(
                output,
                "  <text x=\"{x:.1}\" y=\"{:.1}\" text-anchor=\"middle\" font-family=\"{FONT}\" font-size=\"14\" fill=\"#171d24\">{index}</text>",
                TOP + PLOT_HEIGHT + 23.0
            )?;
        }
    }

    write!(
        output,
        "  <polyline fill=\"none\" stroke=\"#59636f\" stroke-width=\"1.6\" stroke-dasharray=\"7 5\" points=\""
    )?;
    for (x, weight) in x_a.iter().zip(D2Q9::WEIGHTS) {
        write!(output, "{x:.1},{:.1} ", map_y(weight, 0.0, 0.5))?;
    }
    writeln!(output, "\"/>")?;
    for (x, weight) in x_a.iter().zip(D2Q9::WEIGHTS) {
        let y = map_y(weight, 0.0, 0.5);
        writeln!(
            output,
            "  <rect x=\"{:.1}\" y=\"{:.1}\" width=\"8\" height=\"8\" fill=\"#ffffff\" stroke=\"#59636f\" stroke-width=\"1.5\"/>",
            x - 4.0,
            y - 4.0
        )?;
    }

    write!(
        output,
        "  <polyline fill=\"none\" stroke=\"#1f5a91\" stroke-width=\"2\" points=\""
    )?;
    for (x, distribution) in x_a.iter().zip(normalized) {
        write!(output, "{x:.1},{:.1} ", map_y(distribution, 0.0, 0.5))?;
    }
    writeln!(output, "\"/>")?;
    for (x, distribution) in x_a.iter().zip(normalized) {
        let y = map_y(distribution, 0.0, 0.5);
        writeln!(
            output,
            "  <circle cx=\"{x:.1}\" cy=\"{y:.1}\" r=\"4.8\" fill=\"#1f5a91\" stroke=\"#ffffff\" stroke-width=\"1\"/>"
        )?;
    }

    let zero = map_y(0.0, -0.035, 0.035);
    for (x, deviation) in x_b.iter().zip(deviations) {
        let y = map_y(deviation, -0.035, 0.035);
        let color = if deviation >= 0.0 {
            "#1f5a91"
        } else {
            "#a74428"
        };
        writeln!(
            output,
            "  <line x1=\"{x:.1}\" y1=\"{zero:.1}\" x2=\"{x:.1}\" y2=\"{y:.1}\" stroke=\"{color}\" stroke-width=\"2\"/>"
        )?;
        if deviation >= 0.0 {
            writeln!(
                output,
                "  <circle cx=\"{x:.1}\" cy=\"{y:.1}\" r=\"4.8\" fill=\"{color}\"/>"
            )?;
        } else {
            writeln!(
                output,
                "  <rect x=\"{:.1}\" y=\"{:.1}\" width=\"8\" height=\"8\" fill=\"#ffffff\" stroke=\"{color}\" stroke-width=\"1.7\"/>",
                x - 4.0,
                y - 4.0
            )?;
        }
    }

    writeln!(
        output,
        "  <line x1=\"150\" y1=\"43\" x2=\"184\" y2=\"43\" stroke=\"#1f5a91\" stroke-width=\"2\"/><circle cx=\"167\" cy=\"43\" r=\"4.5\" fill=\"#1f5a91\"/><text x=\"192\" y=\"48\" font-family=\"{FONT}\" font-size=\"14\" fill=\"#171d24\">当前平衡分布</text>"
    )?;
    writeln!(
        output,
        "  <line x1=\"294\" y1=\"43\" x2=\"328\" y2=\"43\" stroke=\"#59636f\" stroke-width=\"1.6\" stroke-dasharray=\"7 5\"/><rect x=\"307\" y=\"39\" width=\"8\" height=\"8\" fill=\"#ffffff\" stroke=\"#59636f\" stroke-width=\"1.5\"/><text x=\"336\" y=\"48\" font-family=\"{FONT}\" font-size=\"14\" fill=\"#171d24\">静止权重</text>"
    )?;
    writeln!(
        output,
        "  <circle cx=\"646\" cy=\"43\" r=\"4.5\" fill=\"#1f5a91\"/><text x=\"658\" y=\"48\" font-family=\"{FONT}\" font-size=\"14\" fill=\"#171d24\">正偏差</text><rect x=\"738\" y=\"39\" width=\"8\" height=\"8\" fill=\"#ffffff\" stroke=\"#a74428\" stroke-width=\"1.7\"/><text x=\"754\" y=\"48\" font-family=\"{FONT}\" font-size=\"14\" fill=\"#171d24\">负偏差</text>"
    )?;
    writeln!(
        output,
        "  <text x=\"24\" y=\"204\" transform=\"rotate(-90 24 204)\" text-anchor=\"middle\" font-family=\"{FONT}\" font-size=\"16\" fill=\"#171d24\">fᵢᵉᵠ / ρ</text>"
    )?;
    writeln!(
        output,
        "  <text x=\"474\" y=\"204\" transform=\"rotate(-90 474 204)\" text-anchor=\"middle\" font-family=\"{FONT}\" font-size=\"16\" fill=\"#171d24\">(fᵢᵉᵠ − ρwᵢ) / ρ</text>"
    )?;
    for center in [LEFT_A + PLOT_WIDTH / 2.0, LEFT_B + PLOT_WIDTH / 2.0] {
        writeln!(
            output,
            "  <text x=\"{center:.1}\" y=\"410\" text-anchor=\"middle\" font-family=\"{FONT}\" font-size=\"16\" fill=\"#171d24\">离散速度索引 i</text>"
        )?;
    }
    writeln!(
        output,
        "  <text x=\"{:.1}\" y=\"432\" text-anchor=\"middle\" font-family=\"{FONT}\" font-size=\"13\" fill=\"#59636f\">ρ = {density:.2}，u = ({:.2}, {:.2})</text>",
        WIDTH / 2.0,
        velocity[0],
        velocity[1]
    )?;
    writeln!(output, "</svg>")?;

    Ok(())
}

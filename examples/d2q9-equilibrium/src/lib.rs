//! 可复现的 D2Q9 平衡分布数据图生成。

use kuva::{
    backend::svg::SvgBackend,
    prelude::{Layout, LinePlot, LineStyle, LollipopPlot, Plot},
    render::figure::Figure,
};
use lbm_core::D2Q9;

/// 使用 Kuva 生成带文档级可访问元数据的 D2Q9 平衡分布 SVG。
#[must_use]
pub fn render_equilibrium_svg(
    density: f64,
    velocity: [f64; 2],
    distributions: &[f64; D2Q9::Q],
) -> String {
    let normalized = distributions.map(|distribution| distribution / density);
    let deviations: [f64; D2Q9::Q] =
        std::array::from_fn(|index| normalized[index] - D2Q9::WEIGHTS[index]);

    let equilibrium = LinePlot::new()
        .with_data(indexed(&normalized))
        .with_color("#1f5a91")
        .with_stroke_width(2.0)
        .with_legend("当前平衡分布");
    let weights = LinePlot::new()
        .with_data(indexed(&D2Q9::WEIGHTS))
        .with_color("#59636f")
        .with_stroke_width(1.6)
        .with_line_style(LineStyle::Dashed)
        .with_legend("静止权重");
    let comparison_plots = vec![Plot::Line(equilibrium), Plot::Line(weights)];
    let comparison_layout = Layout::auto_from_plots(&comparison_plots)
        .with_title("平衡分布与静止权重")
        .with_x_label("离散速度索引")
        .with_y_label("归一化分布");

    let deviation = indexed(&deviations).into_iter().fold(
        LollipopPlot::new()
            .with_baseline(0.0)
            .with_baseline_color("#59636f")
            .with_baseline_width(1.2)
            .with_stem_width(2.0)
            .with_dot_radius(4.5),
        |plot, (index, value)| {
            let color = if value >= 0.0 { "#1f5a91" } else { "#a74428" };
            plot.with_colored_point(index, value, color)
        },
    );
    let deviation_plots = vec![Plot::Lollipop(deviation)];
    let deviation_layout = Layout::auto_from_plots(&deviation_plots)
        .with_title("相对静止权重的偏差")
        .with_x_label("离散速度索引")
        .with_y_label("偏差");

    let scene = Figure::new(1, 2)
        .with_plots(vec![comparison_plots, deviation_plots])
        .with_layouts(vec![comparison_layout, deviation_layout])
        .with_labels_lowercase()
        .with_cell_size(450.0, 420.0)
        .render();
    let svg = SvgBackend.render_scene(&scene);
    let description = format!(
        "密度 {density:.2}，宏观速度（{:.2}，{:.2}）时的 D2Q9 平衡分布。左图与静止权重比较，右图显示二者的差。",
        velocity[0], velocity[1]
    );

    add_accessibility_metadata(svg, "D2Q9 平衡分布", &description)
}

fn indexed(values: &[f64; D2Q9::Q]) -> Vec<(f64, f64)> {
    values
        .iter()
        .scan(0.0, |index, value| {
            let point = (*index, *value);
            *index += 1.0;
            Some(point)
        })
        .collect()
}

fn add_accessibility_metadata(mut svg: String, title: &str, description: &str) -> String {
    let root_end = svg.find('>').expect("Kuva SVG must contain a root element");
    svg.insert_str(
        root_end,
        " role=\"img\" aria-labelledby=\"plot-title plot-description\"",
    );
    svg.insert_str(
        root_end + 1 + " role=\"img\" aria-labelledby=\"plot-title plot-description\"".len(),
        &format!(
            "\n<title id=\"plot-title\">{}</title>\n<desc id=\"plot-description\">{}</desc>",
            escape_xml(title),
            escape_xml(description)
        ),
    );
    svg
}

fn escape_xml(text: &str) -> String {
    text.replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
        .replace('"', "&quot;")
        .replace('\'', "&apos;")
}

#[cfg(test)]
mod tests {
    use lbm_core::{D2Q9, equilibrium};

    use super::render_equilibrium_svg;

    #[test]
    fn rendered_data_plot_preserves_semantics_and_accessibility() {
        let density = 1.0;
        let velocity = [0.08, 0.02];
        let distributions = equilibrium(density, velocity);

        let svg = render_equilibrium_svg(density, velocity, &distributions);

        for expected in [
            "<title id=\"plot-title\">D2Q9 平衡分布</title>",
            "<desc id=\"plot-description\">",
            "role=\"img\"",
            "aria-labelledby=\"plot-title plot-description\"",
            "平衡分布与静止权重",
            "相对静止权重的偏差",
            "当前平衡分布",
            "静止权重",
        ] {
            assert!(svg.contains(expected), "missing SVG semantic: {expected}");
        }
        assert_eq!(
            svg.matches("<circle").count(),
            D2Q9::Q,
            "the deviation panel should use one lollipop marker per discrete velocity",
        );
    }
}

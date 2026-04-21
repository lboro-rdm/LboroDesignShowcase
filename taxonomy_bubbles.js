// r2d3 bubble diagram — gptTaxonomy drill-down
//
// `data` passed from R as an array of objects. Two modes:
//
// Level 1 (overview):
//   { level: 1, label, display_label, article_count, category }
//
// Level 2 (drill-down):
//   { level: 2, label, display_label, article_count, category, parent, selected }

const palette = [
  "#D4A843", "#6B8F71", "#C76B4E", "#5B7FA6",
  "#9B6B9B", "#4E8A8A", "#B5734A", "#7A9E3B",
  "#C45C8A", "#4E9E8A", "#A07840", "#5E6FA8",
  "#B86B3A", "#7B5EA8", "#3A8A6E"
];

const allCategories = [
  "geography_places","landscapes_nature","animals_insects",
  "art_movements_styles","design_elements_patterns","architecture_built_environment",
  "fashion_textiles","interiors_products","materials_processes","culture_heritage",
  "history_time_periods","psychology_emotions","social_issues","futurism_speculative",
  "sensory_experience"
];

const w = width;
const h = height;

svg
  .attr("width", w).attr("height", h)
  .style("background", "#0f0f0f")
  .style("font-family", "'Georgia', serif");

svg.selectAll("*").remove();

// ── Defs ──────────────────────────────────────────────────────────────────────
const defs = svg.append("defs");

const pat = defs.append("pattern")
  .attr("id", "dotgrid").attr("width", 24).attr("height", 24)
  .attr("patternUnits", "userSpaceOnUse");
pat.append("circle").attr("cx", 2).attr("cy", 2).attr("r", 1).attr("fill", "#ffffff10");
svg.append("rect").attr("width", w).attr("height", h).attr("fill", "url(#dotgrid)");

const glow = defs.append("filter").attr("id", "glow");
glow.append("feGaussianBlur").attr("stdDeviation", "6").attr("result", "coloredBlur");
const fm1 = glow.append("feMerge");
fm1.append("feMergeNode").attr("in", "coloredBlur");
fm1.append("feMergeNode").attr("in", "SourceGraphic");

const glowSel = defs.append("filter").attr("id", "glow-sel");
glowSel.append("feGaussianBlur").attr("stdDeviation", "10").attr("result", "coloredBlur");
const fm2 = glowSel.append("feMerge");
fm2.append("feMergeNode").attr("in", "coloredBlur");
fm2.append("feMergeNode").attr("in", "SourceGraphic");

// ── Level & parent ────────────────────────────────────────────────────────────
const level     = data[0] ? data[0].level : 1;
const parentKey = data[0] ? data[0].parent : null;
const parentLabel = parentKey
  ? parentKey.replace(/_/g, " ").replace(/\b\w/g, c => c.toUpperCase())
  : null;

// Stable colour per category (same index as allCategories array)
const colorFor = key => palette[allCategories.indexOf(key) % palette.length] || palette[0];
const baseColor = parentKey ? colorFor(parentKey) : palette[0];

// ── Header ────────────────────────────────────────────────────────────────────
svg.append("text")
  .attr("x", 24).attr("y", 40)
  .attr("fill", level === 2 ? baseColor : "#f0ebe0")
  .attr("font-size", "18px").attr("font-weight", "bold").attr("letter-spacing", "0.12em")
  .text(level === 1 ? "TAXONOMY SUBJECTS" : (parentLabel || "KEYWORDS").toUpperCase());

svg.append("text")
  .attr("x", 24).attr("y", 60)
  .attr("fill", "#888").attr("font-size", "11px").attr("letter-spacing", "0.08em")
  .text(level === 1
    ? "bubble size = matching articles · click to drill down"
    : "bubble size = matching articles · click to filter · click ← to return");

// ── Back button (L2) ──────────────────────────────────────────────────────────
if (level === 2) {
  const back = svg.append("g")
    .attr("transform", `translate(${w - 114}, 26)`)
    .style("cursor", "pointer")
    .on("click", () => Shiny.setInputValue("bubble_drilldown", "__back__", { priority: "event" }));

  back.append("rect")
    .attr("width", 94).attr("height", 26).attr("rx", 4)
    .attr("fill", "#ffffff0f").attr("stroke", "#ffffff33").attr("stroke-width", 1);

  back.append("text")
    .attr("x", 47).attr("y", 17).attr("text-anchor", "middle")
    .attr("fill", "#ccc").attr("font-size", "11px").attr("letter-spacing", "0.06em")
    .text("← All Topics");
}

// ── Pack ──────────────────────────────────────────────────────────────────────
const pack = d3.pack()
  .size([w - 40, h - 110])
  .padding(level === 1 ? 14 : 8);

const root = d3.hierarchy({ children: data })
  .sum(d => Math.max(d.article_count || 0, 1));

pack(root);

// ── Bubbles ───────────────────────────────────────────────────────────────────
const g = svg.append("g").attr("transform", "translate(20, 80)");

const node = g.selectAll("g.bubble")
  .data(root.leaves())
  .enter().append("g")
  .attr("class", "bubble")
  .attr("transform", d => `translate(${d.x},${d.y})`)
  .style("cursor", "pointer");

const nodeColor = d => level === 1 ? colorFor(d.data.category) : baseColor;

// Glow ring
node.append("circle")
  .attr("r", d => d.r + 4).attr("fill", "none")
  .attr("stroke", d => nodeColor(d) + (d.data.selected ? "bb" : "33"))
  .attr("stroke-width", d => d.data.selected ? 3 : 2)
  .attr("filter", d => d.data.selected ? "url(#glow-sel)" : "url(#glow)");

// Main circle (animate in)
node.append("circle")
  .attr("r", 0)
  .attr("fill", d => nodeColor(d) + (d.data.selected ? "44" : "22"))
  .attr("stroke", d => nodeColor(d))
  .attr("stroke-width", d => d.data.selected ? 2.5 : 1.5)
  .transition().duration(600).delay((d, i) => i * 40)
  .ease(d3.easeBounceOut)
  .attr("r", d => d.r);

// Dashed ring for selected state
node.filter(d => d.data.selected).append("circle")
  .attr("r", d => d.r + 8).attr("fill", "none")
  .attr("stroke", d => nodeColor(d) + "66")
  .attr("stroke-width", 1).attr("stroke-dasharray", "4 3");

// Label
node.append("text")
  .attr("text-anchor", "middle")
  .attr("dy", d => (d.r > 40 && d.data.article_count > 0) ? "-0.7em" : "0.35em")
  .attr("fill", d => nodeColor(d))
  .attr("font-size", d => Math.min(13, Math.max(7, d.r / 3.8)) + "px")
  .attr("font-weight", "600").attr("letter-spacing", "0.04em")
  .attr("pointer-events", "none")
  .text(d => {
    const lbl = d.data.display_label || d.data.label;
    if (d.r > 48) return lbl;
    if (d.r > 30) return lbl.length > 14 ? lbl.slice(0, 13) + "…" : lbl;
    return lbl.length > 8 ? lbl.slice(0, 7) + "…" : lbl;
  })
  .style("opacity", 0)
  .transition().delay((d, i) => i * 40 + 300).duration(300)
  .style("opacity", 1);

// Article count badge
node.filter(d => d.r > 30).append("text")
  .attr("text-anchor", "middle")
  .attr("dy", d => (d.r > 40 && d.data.article_count > 0) ? "0.9em" : "1.6em")
  .attr("fill", "#ffffffaa")
  .attr("font-size", d => Math.min(11, Math.max(8, d.r / 5)) + "px")
  .attr("pointer-events", "none")
  .text(d => d.data.article_count + (level === 1 ? " articles" : ""))
  .style("opacity", 0)
  .transition().delay((d, i) => i * 40 + 380).duration(300)
  .style("opacity", 1);

// ── Clicks ────────────────────────────────────────────────────────────────────
node.on("click", function(event, d) {
  if (level === 1) {
    // Drill into this category
    Shiny.setInputValue("bubble_drilldown", d.data.label, { priority: "event" });
  } else {
    // Toggle facet filter for this specific term
    Shiny.setInputValue("bubble_term_click", {
      term:     d.data.label,
      category: d.data.category,
      selected: d.data.selected
    }, { priority: "event" });
  }
});

// ── Hover ─────────────────────────────────────────────────────────────────────
node
  .on("mouseover", function(event, d) {
    d3.select(this).select("circle:nth-child(2)")
      .transition().duration(150).attr("fill", nodeColor(d) + "55");
  })
  .on("mouseout", function(event, d) {
    d3.select(this).select("circle:nth-child(2)")
      .transition().duration(150).attr("fill", nodeColor(d) + (d.data.selected ? "44" : "22"));
  });

// ── Legend (L1 only) ──────────────────────────────────────────────────────────
if (level === 1) {
  const cats = Array.from(new Set(data.map(d => d.category)));
  const legendX = w - 215;
  const legendY = h - (cats.length * 20) - 12;
  const legend  = svg.append("g").attr("transform", `translate(${legendX}, ${legendY})`);

  cats.forEach((cat, i) => {
    const row = legend.append("g").attr("transform", `translate(0, ${i * 20})`);
    row.append("circle").attr("r", 5).attr("cx", 5).attr("cy", 5)
      .attr("fill", colorFor(cat) + "44").attr("stroke", colorFor(cat)).attr("stroke-width", 1.5);
    row.append("text").attr("x", 16).attr("y", 10)
      .attr("fill", "#bbb").attr("font-size", "9px").attr("letter-spacing", "0.04em")
      .text(cat.replace(/_/g, " ").replace(/\b\w/g, c => c.toUpperCase()));
  });
}
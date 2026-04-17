// r2d3 bubble diagram — gptTaxonomy top-tier subjects
// `data` is passed from R as an array of:
//   { label, count, article_count, category, selected, first_term }

const palette = [
  "#D4A843", "#6B8F71", "#C76B4E", "#5B7FA6",
  "#9B6B9B", "#4E8A8A", "#B5734A"
];

const w = width;
const h = height;

// ── Canvas ───────────────────────────────────────────────────────────────────
svg
  .attr("width", w)
  .attr("height", h)
  .style("background", "#0f0f0f")
  .style("font-family", "'Georgia', serif");

svg.selectAll("*").remove();

// ── Background dot grid ───────────────────────────────────────────────────────
const defs = svg.append("defs");

const pattern = defs.append("pattern")
  .attr("id", "dotgrid")
  .attr("width", 24).attr("height", 24)
  .attr("patternUnits", "userSpaceOnUse");
pattern.append("circle")
  .attr("cx", 2).attr("cy", 2).attr("r", 1)
  .attr("fill", "#ffffff10");
svg.append("rect")
  .attr("width", w).attr("height", h)
  .attr("fill", "url(#dotgrid)");

// ── Glow filters ─────────────────────────────────────────────────────────────
const glowFilter = defs.append("filter").attr("id", "glow");
glowFilter.append("feGaussianBlur").attr("stdDeviation", "6").attr("result", "coloredBlur");
const feMerge = glowFilter.append("feMerge");
feMerge.append("feMergeNode").attr("in", "coloredBlur");
feMerge.append("feMergeNode").attr("in", "SourceGraphic");

const selectedGlow = defs.append("filter").attr("id", "glow-selected");
selectedGlow.append("feGaussianBlur").attr("stdDeviation", "10").attr("result", "coloredBlur");
const feMerge2 = selectedGlow.append("feMerge");
feMerge2.append("feMergeNode").attr("in", "coloredBlur");
feMerge2.append("feMergeNode").attr("in", "SourceGraphic");

// ── Title ─────────────────────────────────────────────────────────────────────
svg.append("text")
  .attr("x", 24).attr("y", 40)
  .attr("fill", "#f0ebe0")
  .attr("font-size", "18px").attr("font-weight", "bold")
  .attr("letter-spacing", "0.12em")
  .text("TAXONOMY SUBJECTS");

svg.append("text")
  .attr("x", 24).attr("y", 60)
  .attr("fill", "#888")
  .attr("font-size", "11px").attr("letter-spacing", "0.08em")
  .text("bubble size = matching articles · click to filter");

// ── Color map ─────────────────────────────────────────────────────────────────
const categories = Array.from(new Set(data.map(d => d.category)));
const colorMap = {};
categories.forEach((cat, i) => { colorMap[cat] = palette[i % palette.length]; });

// ── Pack layout — sized by article_count ─────────────────────────────────────
const pack = d3.pack()
  .size([w - 40, h - 110])
  .padding(14);

const root = d3.hierarchy({ children: data })
  .sum(d => Math.max(d.article_count || 0, 1));

pack(root);

// ── Draw bubbles ──────────────────────────────────────────────────────────────
const g = svg.append("g").attr("transform", "translate(20, 80)");

const node = g.selectAll("g.bubble")
  .data(root.leaves())
  .enter()
  .append("g")
  .attr("class", "bubble")
  .attr("transform", d => `translate(${d.x},${d.y})`)
  .style("cursor", "pointer");

// Outer glow ring
node.append("circle")
  .attr("r", d => d.r + 4)
  .attr("fill", "none")
  .attr("stroke", d => colorMap[d.data.category] + (d.data.selected ? "bb" : "33"))
  .attr("stroke-width", d => d.data.selected ? 3 : 2)
  .attr("filter", d => d.data.selected ? "url(#glow-selected)" : "url(#glow)");

// Main bubble
node.append("circle")
  .attr("r", 0)
  .attr("fill", d => colorMap[d.data.category] + (d.data.selected ? "44" : "22"))
  .attr("stroke", d => colorMap[d.data.category])
  .attr("stroke-width", d => d.data.selected ? 2.5 : 1.5)
  .transition()
  .duration(600)
  .delay((d, i) => i * 50)
  .ease(d3.easeBounceOut)
  .attr("r", d => d.r);

// Dashed ring for selected state
node.filter(d => d.data.selected)
  .append("circle")
  .attr("r", d => d.r + 8)
  .attr("fill", "none")
  .attr("stroke", d => colorMap[d.data.category] + "66")
  .attr("stroke-width", 1)
  .attr("stroke-dasharray", "4 3");

// Category label
node.append("text")
  .attr("text-anchor", "middle")
  .attr("dy", d => d.r > 42 ? "-0.8em" : "0.35em")
  .attr("fill", d => colorMap[d.data.category])
  .attr("font-size", d => Math.min(13, Math.max(8, d.r / 3.5)) + "px")
  .attr("font-weight", "600")
  .attr("letter-spacing", "0.04em")
  .attr("pointer-events", "none")
  .text(d => {
    const words = d.data.label.replace(/_/g, " ").split(" ");
    if (d.r > 45) return words.map(w => w[0].toUpperCase() + w.slice(1)).join(" ");
    if (d.r > 28) return words.slice(0, 2).map(w => w[0].toUpperCase() + w.slice(1)).join(" ");
    return words[0][0].toUpperCase() + words[0].slice(1);
  })
  .style("opacity", 0)
  .transition().delay((d, i) => i * 50 + 350).duration(300)
  .style("opacity", 1);

// Article count badge (larger bubbles only)
node.filter(d => d.r > 34)
  .append("text")
  .attr("text-anchor", "middle")
  .attr("dy", d => d.r > 42 ? "0.9em" : "1.5em")
  .attr("fill", "#ffffffaa")
  .attr("font-size", d => Math.min(11, Math.max(8, d.r / 5)) + "px")
  .attr("pointer-events", "none")
  .text(d => d.data.article_count + " articles")
  .style("opacity", 0)
  .transition().delay((d, i) => i * 50 + 400).duration(300)
  .style("opacity", 1);

// ── Click handler ─────────────────────────────────────────────────────────────
// Maps taxonomy JSON keys → Shiny selectInput IDs in your server
const facetMap = {
  geography_places:               "facet_geo",
  landscapes_nature:              "facet_nature",
  animals_insects:                "facet_animals",
  art_movements_styles:           "facet_art",
  design_elements_patterns:       "facet_design",
  architecture_built_environment: "facet_architecture",
  fashion_textiles:               "facet_fashion"
};

node.on("click", function(event, d) {
  const inputId = facetMap[d.data.label];
  if (!inputId) return;
  // Toggle: if already selected reset to "All", otherwise set first term
  const newVal = d.data.selected ? "All" : (d.data.first_term || "All");
  Shiny.setInputValue(inputId, newVal, { priority: "event" });
});

// ── Hover highlight ───────────────────────────────────────────────────────────
node
  .on("mouseover", function(event, d) {
    d3.select(this).select("circle:nth-child(2)")
      .transition().duration(150)
      .attr("fill", colorMap[d.data.category] + "55");
  })
  .on("mouseout", function(event, d) {
    d3.select(this).select("circle:nth-child(2)")
      .transition().duration(150)
      .attr("fill", colorMap[d.data.category] + (d.data.selected ? "44" : "22"));
  });

// ── Legend ────────────────────────────────────────────────────────────────────
const legendX = w - 210;
const legendY = h - (categories.length * 22) - 16;
const legend = svg.append("g").attr("transform", `translate(${legendX}, ${legendY})`);

categories.forEach((cat, i) => {
  const row = legend.append("g").attr("transform", `translate(0, ${i * 22})`);
  row.append("circle")
    .attr("r", 6).attr("cx", 6).attr("cy", 6)
    .attr("fill", palette[i % palette.length] + "44")
    .attr("stroke", palette[i % palette.length]).attr("stroke-width", 1.5);
  row.append("text")
    .attr("x", 18).attr("y", 11)
    .attr("fill", "#ccc").attr("font-size", "10px")
    .attr("letter-spacing", "0.05em")
    .text(cat.replace(/_/g, " ").replace(/\b\w/g, c => c.toUpperCase()));
});
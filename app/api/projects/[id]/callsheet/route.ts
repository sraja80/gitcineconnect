import { NextResponse } from "next/server";
import PDFDocument from "pdfkit";

export async function GET(req: Request, { params }: any) {
  try {
    const { id } = params;
    // For demo: static data. In real flow load project and crew from DB.
    const project = { title: "Demo Project", date: new Date().toLocaleDateString(), location: "Chennai", call_time: "06:30 AM", scenes: [{ scene: "1A", location: "Studio A", cast: "Siva" }] };

    const doc = new PDFDocument({ size: "A4", margin: 40 });
    const chunks: any[] = [];
    doc.on("data", (c) => chunks.push(c));
    doc.on("end", () => {});

    doc.fontSize(20).text(`${project.title} — Call Sheet`, { align: "center" });
    doc.moveDown();
    doc.fontSize(12).text(`Date: ${project.date}`);
    doc.text(`Location: ${project.location}`);
    doc.text(`Call time: ${project.call_time}`);
    doc.moveDown();
    doc.fontSize(14).text("Scenes");
    project.scenes.forEach((s) => {
      doc.fontSize(12).text(`${s.scene} — ${s.location} — Cast: ${s.cast}`);
    });
    doc.end();

    const buffer = Buffer.concat(chunks);
    return new NextResponse(buffer, {
      status: 200,
      headers: { "Content-Type": "application/pdf", "Content-Disposition": `attachment; filename="callsheet_${id}.pdf"` }
    });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
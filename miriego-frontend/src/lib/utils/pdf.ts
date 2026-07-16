import jsPDF from 'jspdf';
import autoTable from 'jspdf-autotable';
import type { ExpedienteDetalle, Pase } from '$lib/types/expediente';
import type { ReclamoDetalle } from '$lib/types/reclamo';

function downloadPdf(doc: jsPDF, filename: string) {
	doc.save(filename);
}

function formatDate(iso: string | null | undefined): string {
	if (!iso) return '—';
	return new Date(iso).toLocaleDateString('es-AR');
}

function formatDateTime(iso: string | null | undefined): string {
	if (!iso) return '—';
	return new Date(iso).toLocaleString('es-AR');
}

// ---------------------------------------------------------------------------
// Expediente PDF
// ---------------------------------------------------------------------------

export function generarPdfExpediente(
	expediente: ExpedienteDetalle,
	nombreSector: (id: number) => string,
	nombreInspeccion: (id: number) => string
) {
	const doc = new jsPDF();
	const marginLeft = 14;
	let y = 20;

	// Título
	doc.setFontSize(16);
	doc.setFont('helvetica', 'bold');
	doc.text('EXPEDIENTE', marginLeft, y);
	y += 10;

	doc.setFontSize(11);
	doc.setFont('helvetica', 'normal');

	const rows: [string, string][] = [
		['N° Expediente', expediente.numero_expediente],
		['Expediente GDE', expediente.gde_numero ?? '—'],
		['Estado', expediente.estado],
		['Sector actual', nombreSector(expediente.sector_actual_id)],
		['Asunto', expediente.asunto],
	];

	if (expediente.descripcion) {
		rows.push(['Descripción', expediente.descripcion]);
	}

	rows.push(
		['Iniciador', expediente.iniciador_nombre],
		['DNI/CUIT', expediente.iniciador_dni_cuit ?? '—'],
		['CC', expediente.iniciador_cc ?? '—'],
		['PP', expediente.iniciador_pp ?? '—'],
		['Fecha inicio', formatDate(expediente.fecha_inicio)],
		['Fecha vencimiento', formatDate(expediente.fecha_vencimiento)],
	);

	autoTable(doc, {
		startY: y,
		margin: { left: marginLeft },
		theme: 'plain',
		head: [],
		body: rows,
		columnStyles: {
			0: { fontStyle: 'bold', cellWidth: 50 },
			1: { cellWidth: 120 },
		},
		styles: { fontSize: 10 },
	});

	y = (doc as any).lastAutoTable.finalY + 10;

	// Últimos 3 pases
	const ultimosPases = expediente.pases.slice(-3);
	if (ultimosPases.length > 0) {
		doc.setFontSize(12);
		doc.setFont('helvetica', 'bold');
		textWithBreak(doc, 'Últimos pases', marginLeft, y);
		y += 6;

		autoTable(doc, {
			startY: y,
			margin: { left: marginLeft },
			head: [['Origen', 'Destino', 'Fecha envío', 'Vencimiento', 'Motivo']],
			body: ultimosPases.map((p: Pase) => [
				nombreSector(p.sector_origen_id),
				nombreSector(p.sector_destino_id),
				formatDateTime(p.fecha_envio),
				formatDate(p.fecha_vencimiento),
				p.motivo ?? '—',
			]),
			styles: { fontSize: 9 },
		});
		y = (doc as any).lastAutoTable.finalY + 10;
	}

	// Footer
	doc.setFontSize(8);
	doc.setTextColor(150);
	doc.text(
		`Generado: ${new Date().toLocaleString('es-AR')}`,
		marginLeft,
		doc.internal.pageSize.getHeight() - 10
	);

	downloadPdf(doc, `Expediente_${expediente.numero_expediente}.pdf`);
}

// ---------------------------------------------------------------------------
// Reclamo PDF
// ---------------------------------------------------------------------------

export function generarPdfReclamo(
	reclamo: ReclamoDetalle,
	nombreCanal: (id: number | null | undefined) => string,
	nombreToma: (id: number | null | undefined) => string,
	nombreInspeccion: (id: number | null | undefined) => string,
	nombreTipo: (id: number) => string
) {
	const doc = new jsPDF();
	const marginLeft = 14;
	let y = 20;

	doc.setFontSize(16);
	doc.setFont('helvetica', 'bold');
	doc.text('RECLAMO', marginLeft, y);
	y += 10;

	doc.setFontSize(11);
	doc.setFont('helvetica', 'normal');

	const rows: [string, string][] = [
		['Código', reclamo.codigo_reclamo],
		['Estado', reclamo.estado],
		['Prioridad', reclamo.prioridad],
		['Tipo', nombreTipo(reclamo.tipo_id)],
		['Título', reclamo.titulo],
		['Descripción', reclamo.descripcion],
	];

	if (reclamo.reclamante_nombre || reclamo.reclamante_apellido) {
		rows.push(['Reclamante', `${reclamo.reclamante_nombre ?? ''} ${reclamo.reclamante_apellido ?? ''}`.trim()]);
	}
	if (reclamo.reclamante_dni) rows.push(['DNI', reclamo.reclamante_dni]);
	if (reclamo.reclamante_cc) rows.push(['CC', reclamo.reclamante_cc]);
	if (reclamo.reclamante_pp) rows.push(['PP', reclamo.reclamante_pp]);
	if (reclamo.reclamante_telefono) rows.push(['Teléfono', reclamo.reclamante_telefono]);
	if (reclamo.reclamante_email) rows.push(['Email', reclamo.reclamante_email]);

	rows.push(
		['Canal', nombreCanal(reclamo.canal_id)],
		['Toma', nombreToma(reclamo.toma_id)],
		['Inspección', nombreInspeccion(reclamo.inspeccion_id)],
	);

	if (reclamo.direccion_manual) {
		rows.push(['Dirección', reclamo.direccion_manual]);
	}

	rows.push(
		['Creación', formatDateTime(reclamo.fecha_creacion)],
		['Primera respuesta', formatDateTime(reclamo.fecha_primera_respuesta)],
		['Resolución', formatDateTime(reclamo.fecha_resolucion)],
		['Cierre', formatDateTime(reclamo.fecha_cierre)],
	);

	if (reclamo.numero_expediente) {
		rows.push(['Expediente vinculado', reclamo.numero_expediente]);
	}

	autoTable(doc, {
		startY: y,
		margin: { left: marginLeft },
		theme: 'plain',
		head: [],
		body: rows,
		columnStyles: {
			0: { fontStyle: 'bold', cellWidth: 50 },
			1: { cellWidth: 120 },
		},
		styles: { fontSize: 10 },
	});

	y = (doc as any).lastAutoTable.finalY + 10;

	// Footer
	doc.setFontSize(8);
	doc.setTextColor(150);
	doc.text(
		`Generado: ${new Date().toLocaleString('es-AR')}`,
		marginLeft,
		doc.internal.pageSize.getHeight() - 10
	);

	downloadPdf(doc, `Reclamo_${reclamo.codigo_reclamo}.pdf`);
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function textWithBreak(doc: jsPDF, text: string, x: number, y: number) {
	doc.text(text, x, y);
}

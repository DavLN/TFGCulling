#include "MeshletCommon.hlsli"


VertexOut GetVertexAttributes(uint meshletIndex, uint indice)
{

	float3 ptoCtrlA, ptoCtrlB, ptoCtrlC;
	float posU, posV;
	int iu, iv;
	VertexOut vout;


	// Start Position on knotsU & knotsV vector depending on surface Id
	int surfaceId = ks[4 * meshletIndex];

	// Access to ksquad sub-id (id on surface). Ex: On 5x5 surface, value in interval [0,24]
	int ksquadPerSurface = ks[4 * meshletIndex + 1];

	// knot Interval Position (degree discounted from start and end positions)
	int knotIntervalU = ks[4 * meshletIndex + 2];
	int knotIntervalV = ks[4 * meshletIndex + 3];


	// Compute surface degree (order - 1)
	int degreeU = nurbsOrderU[surfaceId] - 1;
	int degreeV = nurbsOrderV[surfaceId] - 1;

	// ksquad intervals at U and V axis per SPECIFIC surface
	int ksquadCoordU = floor(ksquadPerSurface / knotIntervalV);
	int ksquadCoordV = ksquadPerSurface % knotIntervalV;

	// Triangles level of detail
	int trianglePointU = floor(indice / 9);
	int trianglePointV = indice % 9;

	// Final points of knot interval
	float knotFinalPointU = knotsU[tablaKnots[surfaceId].x + degreeU + ksquadCoordU + 1];
	float knotFinalPointV = knotsV[tablaKnots[surfaceId].y + degreeV + ksquadCoordV + 1];

	// Start points of knot interval
	float knotInitialPointU = knotsU[tablaKnots[surfaceId].x + degreeU + ksquadCoordU];
	float knotInitialPointV = knotsV[tablaKnots[surfaceId].y + degreeV + ksquadCoordV];

	// Interval length adjusted to detail level
	float stepU = trianglePointU * (knotFinalPointU - knotInitialPointU) / 8;
	float stepV = trianglePointV * (knotFinalPointV - knotInitialPointV) / 8;

	// Parametric coordinates of the trinagle points
	posU = stepU + knotsU[tablaKnots[surfaceId].x + degreeU + ksquadCoordU];
	posV = stepV + knotsV[tablaKnots[surfaceId].y + degreeV + ksquadCoordV];

	// Knot vectors interval (+ degrees)
	iu = degreeU + ksquadCoordU;
	iv = degreeV + ksquadCoordV;

	// NURBS Evaluation
	ptoCtrlA = NurbsEval2(surfaceId, iu, iv, posU, posV);
	ptoCtrlB = NurbsEval2(surfaceId, iu, iv, (posU + stepU), posV);
	ptoCtrlC = NurbsEval2(surfaceId, iu, iv, posU, (posV + stepV));

	vout.PositionVS = mul(float4(ptoCtrlA, 1), Globals.WorldView).xyz;
	vout.PositionHS = mul(float4(ptoCtrlA, 1), Globals.WorldViewProj);

	// Assignation of color per surface
	vout.MeshletIndex = surfaceId;

	vout.Normal = -mul(float4(1, 1, 100, 0), Globals.World).xyz;
	//vout.Normal = mul(float4(calcNormal(ptoCtrlA, ptoCtrlB, ptoCtrlC), 0), Globals.World).xyz;

	return vout;
}


[RootSignature(ROOT_SIG)]
[NumThreads(128, 1, 1)]
[OutputTopology("triangle")]
void main(
	uint gtid : SV_GroupThreadID,
	uint gid : SV_GroupID,
	out indices uint3 tris[128],
	out vertices VertexOut verts[81]
)
{
	SetMeshOutputCounts(81, 128);

	if (gtid < 128)
	{
		tris[gtid] = uint3(indiceNurbs[gtid * 3], indiceNurbs[gtid * 3 + 1], indiceNurbs[gtid * 3 + 2]);
	}
	if (gtid < 81)
	{
		verts[gtid] = GetVertexAttributes(gid, gtid);
	}
}

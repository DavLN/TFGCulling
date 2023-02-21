#include "MeshletCommon.hlsli"


// The groupshared payload data to export to dispatched mesh shader threadgroups
groupshared Payload s_Payload;


bool isVisible(uint meshletIndex, float4x4 world, float3 cullPosition) {

	float3 ptoCtrlA, ptoCtrlB, ptoCtrlC;
	float3 ksquadNormal, pointOfViewNormal;
    
	// ks data structure
    int surfaceId = ks[4 * meshletIndex];
	int ksquadPerSurface = ks[4 * meshletIndex + 1];
    int knotIntervalU = ks[4 * meshletIndex + 2];
    int knotIntervalV = ks[4 * meshletIndex + 3];
    
	// Surface degrees (order - 1)
	int degreeU = nurbsOrderU[surfaceId] - 1;
	int degreeV = nurbsOrderV[surfaceId] - 1;
	
	// ksquad intervals at U and V axis per SPECIFIC surface
	int ksquadCoordU = floor(ksquadPerSurface / knotIntervalV);
	int ksquadCoordV = ksquadPerSurface % knotIntervalV;

	// Final point of the knot interval
	float knotFinalPointU = knotsU[tablaKnots[surfaceId].x + degreeU + ksquadCoordU + 1];
	float knotFinalPointV = knotsV[tablaKnots[surfaceId].y + degreeV + ksquadCoordV + 1];

	// Start point of the knot interval
	float knotInitialPointU = knotsU[tablaKnots[surfaceId].x + degreeU + ksquadCoordU];
	float knotInitialPointV = knotsV[tablaKnots[surfaceId].y + degreeV + ksquadCoordV];

	// Knot vectors interval (+ degrees)
	int iu = degreeU + ksquadCoordU;
	int iv = degreeV + ksquadCoordV;

	// 3 Points of a ksquad
	ptoCtrlA = NurbsEval2(ks[4 * meshletIndex], iu, iv, knotInitialPointU, knotInitialPointV);
	ptoCtrlB = NurbsEval2(ks[4 * meshletIndex], iu, iv, knotFinalPointU, knotInitialPointV);
	ptoCtrlC = NurbsEval2(ks[4 * meshletIndex], iu, iv, knotInitialPointU, knotFinalPointV);

	// Normal vectors computation
    ksquadNormal = mul(float4(calcNormal(ptoCtrlA, ptoCtrlB, ptoCtrlC), 0), world).xyz;
	pointOfViewNormal = mul(float4(cullPosition, 0), world).xyz;
	

	if (dot(ksquadNormal, pointOfViewNormal) <= 0) {
		return false;
	}
	
	return true;
}


[RootSignature(ROOT_SIG)]
[NumThreads(AS_GROUP_SIZE, 1, 1)]
void main(
    uint gtid : SV_GroupThreadID, 
    uint dtid : SV_DispatchThreadID,
    uint gid : SV_GroupID
)
{
    bool visible = false;
	uint visibleCount;

	// The meshletIndex cannot be higher than the total amount
	if (dtid < ksquadsTotal[0]) {
		visible = isVisible(dtid, Globals.World, Globals.CullViewPosition);
	}

	// Id of visible elements is stored for renderization
	if (visible) {
		uint index = WavePrefixCountBits(visible);

		s_Payload.MeshletIndices[index] = dtid;
		//s_Payload.MeshletIndices = gid; // Sequential case (1 thread)
	}

    
    visibleCount = WaveActiveCountBits(visible);
    DispatchMesh(visibleCount, 1, 1, s_Payload);
}

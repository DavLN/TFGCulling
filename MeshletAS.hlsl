#include "MeshletCommon.hlsli"


// The groupshared payload data to export to dispatched mesh shader threadgroups
groupshared Payload s_Payload;


bool isVisible(uint ksquadId, float4x4 world, float3 cullPosition) {

	float3 ptoCtrlA, ptoCtrlB, ptoCtrlC;
	float3 surfaceNormal, pointOfViewNormal;
    
	// ks data structure
    int surfaceId = ks[4 * ksquadId];
    int knotIntervalU = ks[4 * ksquadId + 2];
    int knotIntervalV = ks[4 * ksquadId + 3];
    
	// Surface degrees (order - 1)
	int degreeU = nurbsOrderU[surfaceId] - 1;
	int degreeV = nurbsOrderV[surfaceId] - 1;

	// Final points of the surface
	float surfaceFinalPointU = knotsU[tablaKnots[surfaceId].x + degreeU + knotIntervalU];
	float surfaceFinalPointV = knotsV[tablaKnots[surfaceId].y + degreeV + knotIntervalV];

	// Start points of the surface
	float surfaceInitialPointU = knotsU[tablaKnots[surfaceId].x + degreeU];
	float surfaceInitialPointV = knotsV[tablaKnots[surfaceId].y + degreeV];

	int iu = degreeU;
	int iv = degreeV;

	// 3 Points of a surface
	ptoCtrlA = NurbsEval2(surfaceId, iu, iv, surfaceInitialPointU, surfaceInitialPointV);
	ptoCtrlB = NurbsEval2(surfaceId, iu, iv, surfaceFinalPointU, surfaceInitialPointV);
	ptoCtrlC = NurbsEval2(surfaceId, iu, iv, surfaceInitialPointU, surfaceFinalPointV);

	// Normal vectors computation
    surfaceNormal = mul(float4(calcNormal(ptoCtrlA, ptoCtrlB, ptoCtrlC), 0), world).xyz;
	pointOfViewNormal = mul(float4(cullPosition, 0), world).xyz;
	

	if (dot(surfaceNormal, pointOfViewNormal) <= 0) {
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

	// The ksquadId cannot be higher than the total amount
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

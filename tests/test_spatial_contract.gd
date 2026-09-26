@tool
extends McpTestSuite


func suite_name() -> String:
	return "spatial_contract"


func test_floor_volume_excludes_other_storeys() -> void:
	assert_true(SpatialContract.on_floor(Vector3(1, 0, 0), Vector3.ZERO, 2.0))
	assert_true(SpatialContract.on_floor(Vector3(0, 0.5, 0), Vector3.ZERO, 2.0))
	assert_false(SpatialContract.on_floor(Vector3(0, 1.5, 0), Vector3.ZERO, 2.0))
	assert_false(SpatialContract.on_floor(Vector3(0, -1.5, 0), Vector3.ZERO, 2.0))
	assert_false(SpatialContract.on_floor(Vector3(2.1, 0, 0), Vector3.ZERO, 2.0))

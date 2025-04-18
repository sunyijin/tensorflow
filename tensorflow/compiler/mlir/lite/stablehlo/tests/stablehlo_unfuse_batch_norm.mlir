// RUN: odml-to-stablehlo-opt %s -stablehlo-unfuse-batch-norm -cse -verify-diagnostics | FileCheck %s

// CHECK-LABEL: @batchNormInference_2D_inner_features
// CHECK-SAME: %[[X:[^:[:space:]]+]]
// CHECK-SAME: %[[SCALE:[^:[:space:]]+]]
// CHECK-SAME: %[[OFFSET:[^:[:space:]]+]]
// CHECK-SAME: %[[MEAN:[^:[:space:]]+]]
// CHECK-SAME: %[[VARIANCE:[^:[:space:]]+]]
func.func @batchNormInference_2D_inner_features(
    %x: tensor<4x256xf32>, %scale: tensor<256xf32>, %offset: tensor<256xf32>,
    %mean: tensor<256xf32>, %variance: tensor<256xf32>)
    -> (tensor<4x256xf32>) {
  // CHECK: %[[CST:.+]] = stablehlo.constant dense<1.001000e-05> : tensor<f32>
  // CHECK-NEXT: %[[EPS_BCAST:.+]] = stablehlo.broadcast_in_dim %[[CST]], dims = [] : (tensor<f32>) -> tensor<256xf32>
  // CHECK-DAG: %[[VARIANCE_EPS:.+]] = stablehlo.add %[[VARIANCE]], %[[EPS_BCAST]] : tensor<256xf32>
  // CHECK-DAG: %[[VARIANCE_EPS_RSQRT:.+]] = stablehlo.rsqrt %[[VARIANCE_EPS]] : tensor<256xf32>
  // CHECK-DAG: %[[MULTIPLIER:.+]] = stablehlo.multiply %[[VARIANCE_EPS_RSQRT]], %[[SCALE]] : tensor<256xf32>
  // CHECK-DAG: %[[MUL_MEAN:.+]] = stablehlo.multiply %[[MULTIPLIER]], %[[MEAN]] : tensor<256xf32>
  // CHECK-DAG: %[[RHS:.+]] = stablehlo.subtract %[[OFFSET]], %[[MUL_MEAN]] : tensor<256xf32>
  // CHECK-DAG: %[[MULTIPLIER_BCAST:.+]] = stablehlo.broadcast_in_dim %[[MULTIPLIER]], dims = [1] : (tensor<256xf32>) -> tensor<4x256xf32>
  // CHECK-DAG: %[[X_NORMED:.+]] = stablehlo.multiply %[[X]], %[[MULTIPLIER_BCAST]] : tensor<4x256xf32>
  // CHECK-DAG: %[[RHS_BCAST:.+]] = stablehlo.broadcast_in_dim %[[RHS]], dims = [1] : (tensor<256xf32>) -> tensor<4x256xf32>
  // CHECK-DAG: %[[RESULT:.+]] = stablehlo.add %[[X_NORMED]], %[[RHS_BCAST]] : tensor<4x256xf32>
  %0 = "stablehlo.batch_norm_inference"(%x, %scale, %offset, %mean, %variance)
      {epsilon = 1.001000e-05 : f32, feature_index = 1 : i64} :
      (tensor<4x256xf32>, tensor<256xf32>, tensor<256xf32>, tensor<256xf32>,
        tensor<256xf32>) -> tensor<4x256xf32>
  // CHECK-DAG: return %[[RESULT]]
  func.return %0 : tensor<4x256xf32>
}

// -----

// CHECK-LABEL: @batchNormInference_4D_middle_features
// CHECK-SAME: %[[X:[^:[:space:]]+]]
// CHECK-SAME: %[[SCALE:[^:[:space:]]+]]
// CHECK-SAME: %[[OFFSET:[^:[:space:]]+]]
// CHECK-SAME: %[[MEAN:[^:[:space:]]+]]
// CHECK-SAME: %[[VARIANCE:[^:[:space:]]+]]
func.func @batchNormInference_4D_middle_features(
    %x: tensor<3x4x256x6xf32>, %scale: tensor<256xf32>, %offset: tensor<256xf32>,
    %mean: tensor<256xf32>, %variance: tensor<256xf32>)
    -> (tensor<3x4x256x6xf32>) {
  // CHECK: %[[CST:.+]] = stablehlo.constant dense<1.001000e-05> : tensor<f32>
  // CHECK-NEXT: %[[EPS_BCAST:.+]] = stablehlo.broadcast_in_dim %[[CST]], dims = [] : (tensor<f32>) -> tensor<256xf32>
  // CHECK-DAG: %[[VARIANCE_EPS:.+]] = stablehlo.add %[[VARIANCE]], %[[EPS_BCAST]] : tensor<256xf32>
  // CHECK-DAG: %[[VARIANCE_EPS_RSQRT:.+]] = stablehlo.rsqrt %[[VARIANCE_EPS]] : tensor<256xf32>
  // CHECK-DAG: %[[MULTIPLIER:.+]] = stablehlo.multiply %[[VARIANCE_EPS_RSQRT]], %[[SCALE]] : tensor<256xf32>
  // CHECK-DAG: %[[MUL_MEAN:.+]] = stablehlo.multiply %[[MULTIPLIER]], %[[MEAN]] : tensor<256xf32>
  // CHECK-DAG: %[[RHS:.+]] = stablehlo.subtract %[[OFFSET]], %[[MUL_MEAN]] : tensor<256xf32>
  // CHECK-DAG: %[[MULTIPLIER_BCAST:.+]] = stablehlo.broadcast_in_dim %[[MULTIPLIER]], dims = [2] : (tensor<256xf32>) -> tensor<3x4x256x6xf32>
  // CHECK-DAG: %[[RHS_BCAST:.+]] = stablehlo.broadcast_in_dim %[[RHS]], dims = [2] : (tensor<256xf32>) -> tensor<3x4x256x6xf32>
  %0 = "stablehlo.batch_norm_inference"(%x, %scale, %offset, %mean, %variance)
      {epsilon = 1.001000e-05 : f32, feature_index = 2 : i64} :
      (tensor<3x4x256x6xf32>, tensor<256xf32>, tensor<256xf32>, tensor<256xf32>,
        tensor<256xf32>) -> tensor<3x4x256x6xf32>
  func.return %0 : tensor<3x4x256x6xf32>
}

// -----

// CHECK-LABEL: @batchNormInference_dynamic_shape
// Validate that dynamic shapes are handled properly.
// CHECK-SAME: %[[X:[^:[:space:]]+]]
// CHECK-SAME: %[[SCALE:[^:[:space:]]+]]
// CHECK-SAME: %[[OFFSET:[^:[:space:]]+]]
// CHECK-SAME: %[[MEAN:[^:[:space:]]+]]
// CHECK-SAME: %[[VARIANCE:[^:[:space:]]+]]
func.func @batchNormInference_dynamic_shape(
    %x: tensor<?x?x?x?xf32>, %scale: tensor<?xf32>, %offset: tensor<?xf32>,
    %mean: tensor<?xf32>, %variance: tensor<?xf32>)
    -> tensor<?x?x?x?xf32> {
  // CHECK-DAG: %[[EPS:.+]] = stablehlo.constant dense<1.000000e-03> : tensor<f32>
  // CHECK-DAG: %[[VAR_SHAPE:.+]] = shape.shape_of %[[VARIANCE]] : tensor<?xf32> -> tensor<1xindex>
  // CHECK-DAG: %[[EPS_BCAST:.+]] =  stablehlo.dynamic_broadcast_in_dim %[[EPS]], %[[VAR_SHAPE]], dims = [] : (tensor<f32>, tensor<1xindex>) -> tensor<?xf32>
  // CHECK-DAG: %[[VARIANCE_EPS:.+]] = stablehlo.add %[[VARIANCE]], %[[EPS_BCAST]] : tensor<?xf32>
  // CHECK-DAG: %[[R_STDDEV:.+]] = stablehlo.rsqrt %[[VARIANCE_EPS]] : tensor<?xf32>
  // CHECK-DAG: %[[MULTIPLIER:.+]] = stablehlo.multiply %[[R_STDDEV]], %[[SCALE]] : tensor<?xf32>
  // CHECK-DAG: %[[MUL_MEAN:.+]] = stablehlo.multiply %[[MULTIPLIER]], %[[MEAN]] : tensor<?xf32>
  // CHECK-DAG: %[[RHS:.+]] = stablehlo.subtract %[[OFFSET]], %[[MUL_MEAN]] : tensor<?xf32>
  // CHECK-DAG: %[[X_SHAPE:.+]] = shape.shape_of %[[X]] : tensor<?x?x?x?xf32> -> tensor<4xindex>
  // CHECK-DAG: %[[MULTIPLIER_BCAST:.+]] = stablehlo.dynamic_broadcast_in_dim %[[MULTIPLIER]], %[[X_SHAPE]], dims = [1] : (tensor<?xf32>, tensor<4xindex>) -> tensor<?x?x?x?xf32>
  // CHECK-DAG: %[[X_NORMED:.+]] = stablehlo.multiply %[[X]], %[[MULTIPLIER_BCAST]] : tensor<?x?x?x?xf32>
  // CHECK-DAG: %[[RHS_BCAST:.+]] = stablehlo.dynamic_broadcast_in_dim %[[RHS]], %[[X_SHAPE]], dims = [1] : (tensor<?xf32>, tensor<4xindex>) -> tensor<?x?x?x?xf32>
  // CHECK-DAG: %[[RESULT:.+]] = stablehlo.add %[[X_NORMED]], %[[RHS_BCAST]] : tensor<?x?x?x?xf32>
  %0 = "stablehlo.batch_norm_inference"(%x, %scale, %offset, %mean, %variance)
      {epsilon = 0.001 : f32, feature_index = 1 : i64} :
      (tensor<?x?x?x?xf32>, tensor<?xf32>, tensor<?xf32>, tensor<?xf32>,
        tensor<?xf32>) -> tensor<?x?x?x?xf32>
  func.return %0 : tensor<?x?x?x?xf32>
}

// -----

// CHECK-LABEL: @batchNormInference_f64
// Validate that epsilon is properly promoted to f64
// CHECK: %[[CST:.+]] = stablehlo.constant dense<1.000000e+00> : tensor<f64>
// CHECK-NEXT: [[EPS_BCAST:.+]] = stablehlo.broadcast_in_dim %[[CST]], dims = [] : (tensor<f64>) -> tensor<256xf64>
func.func @batchNormInference_f64(
    %x: tensor<4x256xf64>, %scale: tensor<256xf64>, %offset: tensor<256xf64>,
    %mean: tensor<256xf64>, %variance: tensor<256xf64>)
    -> (tensor<4x256xf64>) {
  %0 = "stablehlo.batch_norm_inference"(%x, %scale, %offset, %mean, %variance)
      {epsilon = 1.0 : f32, feature_index = 1 : i64} :
      (tensor<4x256xf64>, tensor<256xf64>, tensor<256xf64>, tensor<256xf64>,
        tensor<256xf64>) -> tensor<4x256xf64>
  func.return %0 : tensor<4x256xf64>
}

// -----

// CHECK-LABEL: @batchNormInference_f16
// Validate that epsilon is properly down to f16
// CHECK: %[[EPS:.+]] = stablehlo.constant dense<1.000000e+00> : tensor<f16>
// CHECK-NEXT: %[[EPS_BCAST:.+]] = stablehlo.broadcast_in_dim %[[EPS]], dims = [] : (tensor<f16>) -> tensor<256xf16>
func.func @batchNormInference_f16(
    %x: tensor<4x256xf16>, %scale: tensor<256xf16>, %offset: tensor<256xf16>,
    %mean: tensor<256xf16>, %variance: tensor<256xf16>)
    -> (tensor<4x256xf16>) {
  %0 = "stablehlo.batch_norm_inference"(%x, %scale, %offset, %mean, %variance)
      {epsilon = 1.0 : f32, feature_index = 1 : i64} :
      (tensor<4x256xf16>, tensor<256xf16>, tensor<256xf16>, tensor<256xf16>,
        tensor<256xf16>) -> tensor<4x256xf16>
  func.return %0 : tensor<4x256xf16>
}

// -----

// Validate that epsilon is overflow
func.func @batchNormInference_f16_overflow(
    %x: tensor<4x256xf16>, %scale: tensor<256xf16>, %offset: tensor<256xf16>,
    %mean: tensor<256xf16>, %variance: tensor<256xf16>)
    -> (tensor<4x256xf16>) {
  // expected-warning @+1 {{Could not convert batch_norm epsilon to target fp type: opStatus = 24}}
  %0 = "stablehlo.batch_norm_inference"(%x, %scale, %offset, %mean, %variance)
      {epsilon = 0.00000001 : f32, feature_index = 1 : i64} :
      (tensor<4x256xf16>, tensor<256xf16>, tensor<256xf16>, tensor<256xf16>,
        tensor<256xf16>) -> tensor<4x256xf16>
  func.return %0 : tensor<4x256xf16>
}

// -----

// CHECK-LABEL: @batchNormTraining_4D_middle_features
// CHECK-SAME: %[[X:[^:[:space:]]+]]
// CHECK-SAME: %[[SCALE:[^:[:space:]]+]]
// CHECK-SAME: %[[OFFSET:[^:[:space:]]+]]
func.func @batchNormTraining_4D_middle_features(
    %x: tensor<3x4x256x6xf32>, %scale: tensor<256xf32>, %offset: tensor<256xf32>)
    -> (tensor<3x4x256x6xf32>) {
  // CHECK: %[[CST:.+]] = stablehlo.constant dense<1.000000e+00> : tensor<f32>
  // CHECK-DAG: %[[CST_AXIS:.+]] = "tf.Const"() <{value = dense<[0, 1, 3]> : tensor<3xi32>}> : () -> tensor<3xi32>
  // CHECK-DAG: %[[X_SHAPE:.+]] = shape.shape_of %[[X]] : tensor<3x4x256x6xf32> -> tensor<4xindex>
  // CHECK-DAG: %[[MEAN:.+]] = "tf.Mean"(%arg0, %[[CST_AXIS]]) <{keep_dims = false}> : (tensor<3x4x256x6xf32>, tensor<3xi32>) -> tensor<256xf32>
  // CHECK-DAG: %[[MEAN_BCAST:.+]] = stablehlo.dynamic_broadcast_in_dim %[[MEAN]], %[[X_SHAPE]], dims = [2] : (tensor<256xf32>, tensor<4xindex>) -> tensor<3x4x256x6xf32>
  // CHECK-DAG: %[[SQ_DIFF:.+]] = "tf.SquaredDifference"(%arg0, %[[MEAN_BCAST]]) : (tensor<3x4x256x6xf32>, tensor<3x4x256x6xf32>) -> tensor<3x4x256x6xf32>
  // CHECK-DAG: %[[VARIANCE:.+]] = "tf.Mean"(%[[SQ_DIFF]], %[[CST_AXIS]]) <{keep_dims = false}> : (tensor<3x4x256x6xf32>, tensor<3xi32>) -> tensor<256xf32>
  // CHECK-DAG: %[[EPS:.+]] = stablehlo.broadcast_in_dim %[[CST]], dims = [] : (tensor<f32>) -> tensor<256xf32>
  // CHECK-DAG: %[[VARIANCE_EPS:.+]] = stablehlo.add %[[VARIANCE]], %[[EPS]] : tensor<256xf32>
  // CHECK-DAG: %[[VARIANCE_EPS_RSQRT:.+]] = stablehlo.rsqrt %[[VARIANCE_EPS]] : tensor<256xf32>
  // CHECK-DAG: %[[MULTIPLIER:.+]] = stablehlo.multiply %[[VARIANCE_EPS_RSQRT]], %[[SCALE]] : tensor<256xf32>
  // CHECK-DAG: %[[MUL_MEAN:.+]] = stablehlo.multiply %[[MULTIPLIER]], %[[MEAN]] : tensor<256xf32>
  // CHECK-DAG: %[[RHS:.+]] = stablehlo.subtract %[[OFFSET]], %[[MUL_MEAN]] : tensor<256xf32>
  // CHECK-DAG: %[[MULTIPLIER_BCAST:.+]] = stablehlo.broadcast_in_dim %[[MULTIPLIER]], dims = [2] : (tensor<256xf32>) -> tensor<3x4x256x6xf32>
  // CHECK-DAG: %[[X_NORMED:.+]] = stablehlo.multiply %[[X]], %[[MULTIPLIER_BCAST]] : tensor<3x4x256x6xf32>
  // CHECK-DAG: %[[RHS_BCAST:.+]] = stablehlo.broadcast_in_dim %[[RHS]], dims = [2] : (tensor<256xf32>) -> tensor<3x4x256x6xf32>
  // CHECK-DAG: %[[RESULT:.+]] = stablehlo.add %[[X_NORMED]], %[[RHS_BCAST]] : tensor<3x4x256x6xf32>
  %0:3 = "stablehlo.batch_norm_training"(%x, %scale, %offset)
      {epsilon = 1.0 : f32, feature_index = 2 : i64} :
      (tensor<3x4x256x6xf32>, tensor<256xf32>, tensor<256xf32>) -> (tensor<3x4x256x6xf32>, tensor<256xf32>, tensor<256xf32>)
  func.return %0 : tensor<3x4x256x6xf32>
}

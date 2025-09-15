#include <cuda_runtime.h>
#include <iostream>

int main(){
  int deviceCount = 0;
  cudaError_t error_id = cudaGetDeviceCount(&deviceCount);

  if (error_id != cudaSuccess) {
    printf("Result = FAILED\n");
  }else{
    printf("Result = PASSWD, GPU#=%d\n", deviceCount);
  }
  return error_id;
}

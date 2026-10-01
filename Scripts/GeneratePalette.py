from pathlib import Path
from typing import Annotated
import numpy as np
from coreai.authoring import AIProgram, Module, TensorSpec
from coreai._compiler.dialects import coreai as ops
from coreai._compiler.ir import Value

# Original colour centres. This graph scores mean RGB by squared distance;
# it is a palette heuristic, not a trained scene classifier.
centres = np.array([[0.1,0.1,0.1],[0.9,0.9,0.9],[0.5,0.5,0.5],[0.85,0.15,0.15],[0.15,0.65,0.2],[0.15,0.3,0.85],[0.9,0.65,0.1],[0.65,0.2,0.7],[0.5,0.3,0.15]],dtype=np.float32)
input_spec = TensorSpec(shape=[1,3],dtype=np.float32)
output_spec = TensorSpec(shape=[9],dtype=np.float32,name='distances')
module = Module.create()
with module:
 @ops.graph
 def main(rgb: Annotated[Value,input_spec]) -> Annotated[Value,output_spec]:
  difference = ops.broadcasting_sub(rgb,centres)
  return ops.reshape(ops.reduce_sum(ops.mul(difference,difference),np.array([1],dtype=np.int32)),[9])
module.verify()
output=Path(__file__).resolve().parents[1] / 'Resources/Palette.aimodel'
output.parent.mkdir(parents=True,exist_ok=True)
AIProgram(module).save_asset(output)
print('Created original palette model',sum(p.stat().st_size for p in output.rglob('*') if p.is_file()),'bytes')

float pow5(float x){
	float xx = x*x;
	return xx * xx * x;
}

#pragma glslify: export(pow5)
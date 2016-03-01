function Output = CRC5_gen(Input)

GenPoly = [1 1 0 1 0 1];
%G(x)=x5+ x4+x2+1
Input = [ Input zeros(1,5)];
while length(Input)>=7
    if Input(1) == 1
    temp1 = xor(Input(1:6), GenPoly);
    Input = [ temp1 Input(7:end)];
    else 
        temp1 = Input(2:6);
        Input = [ temp1 Input(7:end)];
    end
end
if Input(1) == 1
    temp1 = xor(Input(1:6), GenPoly);
    temp1 = temp1(2:6);
else
    temp1 = Input(2:6);
end
    temp1 = temp1(end:-1:1);
Output = fliplr(temp1);
function Output = CRC3_gen(Input,m)

GenPoly = [1 0 1 1];   %多项式：X^3+X+1
k =3;                  %k表示多项式的级数
Input = [ Input(1:m) zeros(1,k)];
while length(Input)>=k+2
    if Input(1) == 1
    temp1 = xor(Input(1:k+1), GenPoly);
    Input = [ temp1 Input(k+2:end)];
    else
        temp1 = Input(2:k+1);
        Input = [ temp1 Input(k+2:end)];
    end
end
if Input(1) == 1
    temp1 = xor(Input(1:k+1), GenPoly);
    temp1 = temp1(2:k+1);
else
    temp1 = Input(2:k+1);
end
    temp1 = temp1(end:-1:1);
Output = fliplr(temp1);

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

ENTITY crc_scrambler IS
GENERIC(N:INTEGER:=8);
PORT(
	  addr : IN STD_LOGIC_VECTOR(20 DOWNTO 0);
	  arst : IN STD_LOGIC;
	  clk : IN STD_LOGIC;
	  data_in : IN STD_LOGIC_VECTOR(N-1 DOWNTO 0);
	  data_out : OUT STD_LOGIC_VECTOR(N-1 DOWNTO 0);
	  in_valid : IN STD_LOGIC_VECTOR(N-1 DOWNTO 0);
	  out_valid : OUT STD_LOGIC_VECTOR(N-1 DOWNTO 0);
	  rtl_out : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);--将RTL产生的32位CRC引到textbench中与matlab产生的CRC相比较，全部测试完后删除该端口
	  rd : IN STD_LOGIC;
	  wr : IN STD_LOGIC
	  );
END ENTITY;
ARCHITECTURE crc_sc OF crc_scrambler IS
-------------------------------------------------------------
FUNCTION invert (data:STD_LOGIC_VECTOR;addr:STD_LOGIC)RETURN STD_LOGIC_VECTOR IS
VARIABLE temp:STD_LOGIC_VECTOR(N-1 DOWNTO 0);
        BEGIN
        IF(addr='1')THEN
          FOR i IN N-1 DOWNTO 0 LOOP
             temp(N-1-i):=data(i);
          END LOOP;
        ELSE
	          temp:=data;
        END IF;
        RETURN temp;
END FUNCTION;
--倒置函数
-------------------------------------------------------------
FUNCTION div(data:STD_LOGIC; reg,poly:STD_LOGIC_VECTOR)RETURN STD_LOGIC_VECTOR IS
VARIABLE div_reg:STD_LOGIC_VECTOR(31 DOWNTO 0);
        BEGIN
          div_reg(0):=data XOR(reg(31)AND poly(0));
		  FOR i IN 0 TO 30 LOOP
          div_reg(1+i):=reg(0+i)XOR(reg(31)AND poly(1+i));
        END LOOP;
        RETURN div_reg;
END FUNCTION;
--CRC运算函数
--------------------------------------------------------------
FUNCTION mov(reg:STD_LOGIC_VECTOR;data:STD_LOGIC)RETURN STD_LOGIC_VECTOR IS
VARIABLE sc_reg:STD_LOGIC_VECTOR(31 DOWNTO 0);
        BEGIN
          sc_reg(0):=data;
        FOR i IN 1 TO 31 LOOP
          sc_reg(i):=reg(i-1);
        END LOOP;
        RETURN sc_reg;
END FUNCTION;
--移位函数
---------------------------------------------------------------
FUNCTION SC_F(reg,poly:STD_LOGIC_VECTOR)RETURN STD_LOGIC IS
VARIABLE temp:STD_LOGIC:='0';
        BEGIN
        FOR i IN 0 TO 31 LOOP
           temp:=temp XOR (reg(i)AND poly(i));
        END LOOP;
        RETURN temp;
END FUNCTION;
--求异或函数
----------------------------------------------------------------
BEGIN
PROCESS(arst,clk)
VARIABLE middle_data1:STD_LOGIC;--存放扰码器的抽头异或值
VARIABLE middle_data2:STD_LOGIC;--存放抽头与输入数据的异或值
VARIABLE sc_reg:STD_LOGIC_VECTOR(31 DOWNTO 0):=(OTHERS=>'1');--扰码器的32位寄存器
VARIABLE crc_reg:STD_LOGIC_VECTOR(31 DOWNTO 0):=(OTHERS=>'0');--CRC的32位寄存器，因为CRC与扰码器的寄存器的初值不同，所以定义了俩个寄存器
VARIABLE out_temp:STD_LOGIC_VECTOR(31 DOWNTO 0):=(OTHERS=>'0');--用于从存放CRC32位寄存器中的值并将其左移32个零
VARIABLE crc_temp:STD_LOGIC_VECTOR(31 DOWNTO 0):=(OTHERS=>'0');--当rd有效时，将CRC的值存贮，并读出
VARIABLE out_valid_temp:STD_LOGIC_VECTOR(31 DOWNTO 0):=(OTHERS=>'0');--存储输出有效位，当rd有效时读出
VARIABLE sel:STD_LOGIC_VECTOR(1 DOWNTO 0);--用以选择扰码器的模式与加解扰
VARIABLE zero:STD_LOGIC_VECTOR(N-1 DOWNTO 0):=(OTHERS=>'0');--定值0（与输入位宽相同）
VARIABLE data_temp:STD_LOGIC_VECTOR(N-1 DOWNTO 0):=(OTHERS=>'0');--存储输入数据并根据字节与字的顺序调整
VARIABLE data_valid_temp:STD_LOGIC_VECTOR(N-1 DOWNTO 0):=(OTHERS=>'0');--存储输入数据有效位并根据字节与字的顺序调整
VARIABLE L_data_temp:STD_LOGIC_VECTOR(7 DOWNTO 0):=(OTHERS=>'0');--存储低8位输入数据，当先输入的是低8位时先将低8位存起来，在高8位输入后再输入这里的数据完成顺序转换
VARIABLE L_data_valid_temp:STD_LOGIC_VECTOR(7 DOWNTO 0):=(OTHERS=>'0');--存储低8位输入数据有效位，同上
VARIABLE poly_all:STD_LOGIC_VECTOR(32 DOWNTO 0):=(OTHERS=>'0');--存放多项式
VARIABLE circ_cnt:INTEGER:=0;--计数，在高8位与低8位之间来回跳变
VARIABLE cnt:INTEGER:=33;--计数，将addr中的多项式从高到低赋给poly_all
VARIABLE cnt1:INTEGER:=0;--计数，当选择扰码器功能时将poly_all中的有效多项式移至低位
VARIABLE cnt2:INTEGER:=0;--计数，在rd有效时，记一次数，使crc_temp时钟保持rd跳变时的out_temp
VARIABLE poly_wide:INTEGER:=-1;--计数多项式位数，因为CRCn的多项式是n+1位的所以将其初值赋为-1
BEGIN
IF(arst='0')THEN
  data_out<=(OTHERS=>'0');
  out_valid<=(OTHERS=>'0');
  rtl_out<=(OTHERS=>'0');
ELSIF(clk='1'AND clk'EVENT)THEN
--------------------------------------------------------
    IF(addr(7 downto 0)/=zero)THEN                      --根据addr（7~0）位是否为1将addr（15~8）中的多项式代入poly_all中
	     cnt:=cnt-8;
        FOR i IN N-1 DOWNTO 0 LOOP
           IF(addr(i)='1')THEN
	          poly_all(cnt+i):=addr(i+8);
				 poly_wide:=poly_wide+1;
			  END IF;
		  END LOOP;
    END IF;
--------------------------------------------------------
    IF(wr='0')THEN                                      --根据addr（17~16）将输入的数据顺序调整为从高字节到地直接从高位到低位
        IF(addr(17)='1')THEN--17：Byte（1低0高）
		    IF(circ_cnt=0)THEN
			    data_temp:=invert(data_in,addr(16));
			    data_valid_temp:=invert(in_valid,addr(16));
			    circ_cnt:=1;
		    ELSIF(circ_cnt=1)THEN
		       data_temp:=L_data_temp;
			    data_valid_temp:=L_data_valid_temp;
		       L_data_temp:=invert(data_in,addr(16));--16：bit（1低0高）
			    L_data_valid_temp:=invert(in_valid,addr(16));
			    circ_cnt:=0;
		    END IF;
        ELSE
	       data_temp:=invert(data_in,addr(16));
			 data_valid_temp:=invert(in_valid,addr(16));
	     END IF;
--------------------------------------------------------
		  IF(addr(18)='0')THEN                            --根据addr（18）是否为0，判定是否进入扰码器功能
		    sel:=addr(20)&addr(19);                       --根据addr（20~19）判定扰码器模式
	       FOR i IN 0 TO 32 LOOP
	          poly_all:=poly_all(31 DOWNTO 0)& poly_all(32);
	          cnt1:=cnt1+1;
	          IF(cnt1=poly_wide)THEN
	          EXIT;
	          END IF;
		    END LOOP;--将多项式的位置稍加调整。因为当多项式小于32级时，CRC将多项式放入poly_all的高位比较计算方便，而扰码器放入低位比较方便
	       FOR i IN N-1 DOWNTO 0 LOOP
	          IF(data_valid_temp(i)='1')THEN
	             middle_data1:=SC_F(sc_reg,poly_all);
		          middle_data2:=middle_data1 XOR data_temp(i);
		          CASE sel IS
		              WHEN "11" => sc_reg:=mov(sc_reg,middle_data2);--模式二加码
					     WHEN "10" => sc_reg:=mov(sc_reg,data_temp(i));  --模式二解码
		              WHEN "01" => sc_reg:=mov(sc_reg,middle_data1);--模式一加码
		              WHEN "00" => sc_reg:=mov(sc_reg,middle_data1);--模式一解码
					     WHEN OTHERS => NULL;
		          END CASE;
		         out_temp(i):=middle_data2;
		         out_valid_temp(i):='1';
		       ELSE
		         out_temp(i):='0';
		         out_valid_temp(i):='0';
		       END IF;
		    END LOOP;

	     ELSE
--------------------------------------------------------
		    FOR i IN N-1 DOWNTO 0 LOOP                    --如果addr（18）为1则进入CRC功能
		       IF(data_valid_temp(i)='1')THEN
		          crc_reg:=div(data_temp(i),crc_reg,poly_all);
		       END IF;
		    END LOOP;
					 out_temp:=crc_reg;
			 FOR i IN 0 TO 31 LOOP
			       out_temp:=div(zero(0),out_temp,poly_all);
		    END LOOP;
        END IF;
--------------------------------------------------------
		END IF;
	 IF(addr(18)='1')THEN                                --当数据传递给输出端口
	   IF(rd='0')THEN                                    --当选择CRC功能时，输出受rd控制，当rd为低电平时，输出按每次8位输出从wr变为0到rd变为0的这段时间（或者是wr为0的这段时间）内输入端口输入的有效数据的CRC码
		  IF(cnt2=0)THEN
		    crc_temp:=out_temp;
			 cnt2:=cnt2+1;
		  END IF;
		  FOR i IN N-1 DOWNTO 0 LOOP
           IF(cnt1<poly_wide)THEN
	        	 data_out(i)<= crc_temp(31-cnt1);
				 out_valid(i)<='1';
				 cnt1:=cnt1+1;
			  ELSE
			    data_out(i)<='0';
	          out_valid(i)<='0';
			  END IF;
		  END LOOP;
		END IF;
	 ELSE
	 data_out<=out_temp(7 DOWNTO 0);                  --当选择扰码器功能时，输出不受rd控制，当输入有数据输入时，输出延后一个周期也有数据输出
	 out_valid<=out_valid_temp(7 DOWNTO 0);
	 END IF;
	 rtl_out<=crc_temp;
--------------------------------------------------------
END IF;
END PROCESS;
END ARCHITECTURE;

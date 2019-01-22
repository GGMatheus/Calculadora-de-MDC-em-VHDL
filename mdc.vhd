-- Matheus Guilherme Goncalves 9345126
-- Marcos Hora Gomes de Sá 10394382

library ieee;
use ieee.numeric_bit.all;

-- MDC
entity mdc is
  port (
    X, Y  : in  signed(3 downto 0); -- entradas
    S     : out signed(3 downto 0); -- saida
    reset : in  bit; -- reset ativo alto assíncrono
--    done  : out bit; -- alto quando terminou de calcular
    clk   : in bit;
	 teste : out signed(2 downto 0)
  );
end entity mdc;

architecture comp of mdc is
  component mdc_fd is
    port (
      M, N     : in  signed(3 downto 0); -- entradas
      S        : out signed(3 downto 0); -- saida
      ldX, ldY, ldM : in  bit; -- controle dos loads de X, Y e M
      selIn, selSub : in  bit; -- controle dos multiplexadores de entrada e do somador/subtrator
      XneqY, XltY   : out  bit; -- saidas do comparador X!=Y e X<Y
      clk   : in  bit
    );
  end component;
  component mdc_uc is
    port (
      ldX, ldY, ldM : out bit; -- controle dos loads de X, Y e M
      selIn, selSub : out bit; -- controle dos multiplexadores de entrada e do somador/subtrator
      XneqY, XltY   : in  bit; -- saidas do comparador X!=Y e X<Y
      reset : in  bit; -- reset ativo alto assíncrono
--      done  : out bit; -- alto quando terminou de calcular
      clk   : in  bit;
		teste : out signed (2 downto 0)
    );
  end component;
  signal ldX, ldY, ldM, selIn, selSub, XneqY, XltY: bit;
begin
  fd: mdc_fd port map(X,Y,S,ldX, ldY, ldM, selIn, selSub, XneqY, XltY, clk);
  uc: mdc_uc port map(ldX, ldY, ldM, selIn, selSub, XneqY, XltY, reset, clk, teste);
end architecture;


library ieee;
use ieee.numeric_bit.all;

entity mdc_fd is
	port (
		   M, N     : in  signed(3 downto 0); -- entradas
			S        : out signed(3 downto 0); -- saida
			ldX, ldY, ldM : in  bit; -- controle dos loads de X, Y e M
			selIn, selSub : in  bit; -- controle dos multiplexadores de entrada e do somador/subtrator
			XneqY, XltY   : out  bit; -- saidas do comparador X!=Y e X<Y
			clk   : in  bit
	);
end entity mdc_fd;

architecture estrutura of mdc_fd is
	component registrador_4bits is
		port (
			D : in signed (3 downto 0);
			ldD: in bit;
			clock: in bit;
			Q0: out signed (3 downto 0)
		);
	end component;
	
	component mux2_1 is
		port (
			a0, b0: in signed (3 downto 0);
			sel: in bit;
			saida: out signed (3 downto 0)
		);
	end component;
	
	component comparador_4bits is
		port (
			A, B: in signed (3 downto 0);
			AeqB, AltB, AgtB: out bit
		);
	end component;
	
	component subtrator_4bits is
		port (
			A, B: in signed (3 downto 0);
			S0: out signed (3 downto 0)
		);
	end component;
	
signal s_regA, s_regB: signed (3 downto 0);
signal s_AmenosB: signed (3 downto 0);
signal s_muxA, s_muxB, s_muxC, s_muxD: signed (3 downto 0);
	
begin
	regA: registrador_4bits port map(D => s_muxA, ldD => ldX, clock => clk, Q0 => s_regA);
	regB: registrador_4bits port map(D => s_muxB, ldD => ldY, clock => clk, Q0 => s_regB);
	regM: registrador_4bits port map(D => s_regA, ldD => ldM, clock => clk, Q0 => S);
	
	subtrator: subtrator_4bits port map(A => s_muxC, B => s_muxD, S0 => s_AmenosB);
	
	muxA: mux2_1 port map (a0 => M, b0 => s_AmenosB, sel => selIn, saida => s_muxA);
	muxB: mux2_1 port map (a0 => N, b0 => s_AmenosB, sel => selIn, saida => s_muxB);
	muxC: mux2_1 port map (a0 => s_regA, b0 => s_regB, sel => selSub, saida => s_muxC);
	muxD: mux2_1 port map (a0 => s_regB, b0 => s_regA, sel => selSub, saida => s_muxD);
	
	comparador: comparador_4bits port map (A => s_regA, B => s_regB, AeqB => XneqY, AltB => XltY, AgtB => open);
	
end estrutura;

-- MDC Unidade de Controle
library ieee;
use ieee.numeric_bit.all;

entity mdc_uc is
	port (
		ldX, ldY, ldM : out bit; -- controle dos loads de X, Y e M
		selIn, selSub : out bit; -- controle dos multiplexadores de entrada e do somador/subtrator
		XneqY, XltY   : in  bit; -- saidas do comparador X!=Y e X<Y
		reset : in  bit; -- reset ativo alto assíncrono
--		done  : out bit; -- alto quando terminou de calcular
		clk   : in  bit;
		teste : out signed (2 downto 0)

	);
end mdc_uc;

architecture comportamento of mdc_uc is
	type estado is (testeEq, xMajy, yMajx, xMinusy, yMinusx, fim);
    signal estado_atual , proximo_estado : estado;
	 signal s_testeEq, s_xMajy, s_yMajx, s_xMinusy, s_yMinusx, s_fim: signed (3 downto 0);
begin
	process (reset, clk)
	begin
		if reset = '1' then
			estado_atual <= testeEq;
		elsif (clk' event and clk = '1') then
			estado_atual <= proximo_estado; 
		end if;
	end process;
	
	process (estado_atual, XneqY, XltY)
	begin
		case estado_atual is
			when testeEq =>
				if (XltY = '1') then
					proximo_estado <= yMajx;
				elsif ((XltY = '0') and (XneqY = '1')) then
					proximo_estado <= xMajy;
				else 
					proximo_estado <= fim;
				end if;

			when xMajy =>
				if (XltY = '1') then
					proximo_estado <= yMajx;
				elsif ((XltY = '0') and (XneqY = '1')) then
					proximo_estado <= xMinusy;
				else
					proximo_estado <= fim;
				end if;

			when yMajx =>
				if ((XltY = '0') and (XneqY = '1')) then
					proximo_estado <= xMajy;
				elsif (XltY = '1') then
					proximo_estado <= yMinusx;
				else
					proximo_estado <= fim;
				end if;

			when xMinusy =>
					proximo_estado <= xMajy;

			when yMinusx =>
					proximo_estado <= yMajx;

			when fim =>
				proximo_estado <= fim;
		end case;
	end process;
	
	process (estado_atual)
    begin
  
    ldX <= '0'; ldY <= '0'; ldM <= '0'; 
    selIn <= '0'; selSub <= '0'; 

    case estado_atual is
        when testeEq =>
                   ldX <= '1';
                   ldY <= '1';
				   ldM <= '0';
				   selIn <= '0';
				   selSub <= '0';
					teste <= "000";

        when xMajy => 
                   ldX <= '0'; 
				   ldY <= '0'; 
				   ldM <= '0'; 
                   selIn <= '1';
				   selSub <= '0';
					teste <= "001";

        when yMajx =>
                   ldX <= '0'; 
				   ldY <= '0'; 
				   ldM <= '0'; 
				   selIn <= '0';
				   selSub <= '0';
					teste <= "010";
					
        when xMinusy =>
                   ldX <= '1'; 
				   ldY <= '0'; 
				   ldM <= '0';
				   selIn <= '1';
				   selSub <= '0';
					teste <= "011";
					
        when yMinusx =>
                   ldX <= '0'; 
				   ldY <= '1'; 
				   ldM <= '0';
				   selIn <= '1';
				   selSub <= '1';
					teste <= "100";
					
        when fim =>
                   ldX <= '0'; 
				   ldY <= '0'; 
				   ldM <= '1';
				   selIn <= '0';
				   selSub <= '0';
					teste <= "101";
					
    end case;
    end process;
	
end comportamento;

-- Logica Combinatoria

library ieee;
use ieee.numeric_bit.all;
entity mux2_1 is
	port (
		a0, b0: in signed (3 downto 0);
		sel: in bit;
		saida: out signed (3 downto 0)
	);
end mux2_1;

architecture comportamento of mux2_1 is
begin
	saida <= a0 when (sel = '1') else
		 b0 when (sel = '0');
end comportamento;

library ieee;
use ieee.numeric_bit.all;
entity registrador_4bits is
	port (
		D : in signed (3 downto 0);
		ldD: in bit;
		clock: in bit;
		Q0: out signed (3 downto 0)
	);
end registrador_4bits;

architecture comportamento of registrador_4bits is 
begin
	process (clock)
	begin
		if (clock' event and clock = '1') then
			if (ldD = '1') then
				Q0 <= D;
			end if;
		end if;
	end process;
end comportamento;

library ieee;
use ieee.numeric_bit.all;
entity comparador_4bits is
	port (
		A, B: in signed (3 downto 0);
		AeqB, AltB, AgtB: out bit
	);
end comparador_4bits;

architecture comportamento of comparador_4bits is
begin
	AeqB <= '1' when (A = B) else '0';
	AgtB <= '1' when (A > B) else '0';
	AltB <= '1' when (A < B) else '0';
end comportamento;

library ieee;
use ieee.numeric_bit.all;


entity subtrator_4bits is
	port (
		A, B: in signed (3 downto 0);
		S0: out signed (3 downto 0)
	);
end subtrator_4bits;

architecture comportamento of subtrator_4bits is
	signal AmenosB: signed (3 downto 0);
	
begin
	AmenosB <= A - B;
    S0 <= AmenosB;
end comportamento;
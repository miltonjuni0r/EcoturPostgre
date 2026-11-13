--
-- PostgreSQL database dump
--

\restrict wpYH5UsTcuKuknYIi9Kzbqjtf3Q0ITd22mgZpEQVXeVPq1kiS6l58V9bCPCCL2x

-- Dumped from database version 18.4
-- Dumped by pg_dump version 18.4

-- Started on 2026-11-13 17:02:28

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 7 (class 2615 OID 25112)
-- Name: contabil; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA contabil;


ALTER SCHEMA contabil OWNER TO postgres;

--
-- TOC entry 872 (class 1247 OID 25115)
-- Name: forma; Type: TYPE; Schema: contabil; Owner: postgres
--

CREATE TYPE contabil.forma AS ENUM (
    'PIX',
    'BOLETO',
    'CARTAO',
    'A_VISTA'
);


ALTER TYPE contabil.forma OWNER TO postgres;

--
-- TOC entry 889 (class 1247 OID 25396)
-- Name: natureza_conta_enum; Type: TYPE; Schema: contabil; Owner: postgres
--

CREATE TYPE contabil.natureza_conta_enum AS ENUM (
    'Devedora',
    'Credora'
);


ALTER TYPE contabil.natureza_conta_enum OWNER TO postgres;

--
-- TOC entry 886 (class 1247 OID 25385)
-- Name: tipo_conta_enum; Type: TYPE; Schema: contabil; Owner: postgres
--

CREATE TYPE contabil.tipo_conta_enum AS ENUM (
    'Ativo',
    'Passivo',
    'Patrimonio_liquido',
    'Receita',
    'Despesa'
);


ALTER TYPE contabil.tipo_conta_enum OWNER TO postgres;

--
-- TOC entry 250 (class 1255 OID 25449)
-- Name: fn_atualiza_saldo(); Type: FUNCTION; Schema: contabil; Owner: postgres
--

CREATE FUNCTION contabil.fn_atualiza_saldo() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_natureza_debito contabil.natureza_conta_enum;
    v_natureza_credito contabil.natureza_conta_enum;
BEGIN
    -- Se algum dado essencial for NULL, nao altera nenhum saldo.
    IF NEW.conta_debito_id IS NULL
       OR NEW.conta_credito_id IS NULL
       OR NEW.valor IS NULL THEN
        RETURN NEW;
    END IF;

    -- Consulta a natureza da conta debitada.
    SELECT natureza_conta
      INTO v_natureza_debito
      FROM contabil.plano_contas
     WHERE id = NEW.conta_debito_id;

    -- Consulta a natureza da conta creditada.
    SELECT natureza_conta
      INTO v_natureza_credito
      FROM contabil.plano_contas
     WHERE id = NEW.conta_credito_id;

    -- Protecao adicional: se nao encontrou a natureza, nao altera saldos.
    IF v_natureza_debito IS NULL OR v_natureza_credito IS NULL THEN
        RETURN NEW;
    END IF;

    -- Conta DEVEDORA: debito aumenta o saldo; CREDORA: diminui.
    IF v_natureza_debito = 'Devedora' THEN
        UPDATE contabil.saldo_contas
           SET saldo = saldo + NEW.valor, data_atualizacao = NOW()
         WHERE conta_id = NEW.conta_debito_id;
    ELSE
        UPDATE contabil.saldo_contas
           SET saldo = saldo - NEW.valor, data_atualizacao = NOW()
         WHERE conta_id = NEW.conta_debito_id;
    END IF;

    -- Conta DEVEDORA: credito diminui o saldo; CREDORA: aumenta.
    IF v_natureza_credito = 'Devedora' THEN
        UPDATE contabil.saldo_contas
           SET saldo = saldo - NEW.valor, data_atualizacao = NOW()
         WHERE conta_id = NEW.conta_credito_id;
    ELSE
        UPDATE contabil.saldo_contas
           SET saldo = saldo + NEW.valor, data_atualizacao = NOW()
         WHERE conta_id = NEW.conta_credito_id;
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION contabil.fn_atualiza_saldo() OWNER TO postgres;

--
-- TOC entry 238 (class 1255 OID 25354)
-- Name: fn_validar_pagamento_reserva(); Type: FUNCTION; Schema: contabil; Owner: postgres
--

CREATE FUNCTION contabil.fn_validar_pagamento_reserva() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_status_reserva site.status_reserva;
BEGIN
    SELECT status
      INTO v_status_reserva
      FROM site.reservas
     WHERE id_reserva = NEW.id_reserva;

    IF v_status_reserva = 'Cancelada' THEN
        RAISE EXCEPTION
            'Não é possível registrar ou transferir um pagamento para a reserva % porque ela está cancelada.',
            NEW.id_reserva;
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION contabil.fn_validar_pagamento_reserva() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 234 (class 1259 OID 25415)
-- Name: lancamentos; Type: TABLE; Schema: contabil; Owner: postgres
--

CREATE TABLE contabil.lancamentos (
    id integer NOT NULL,
    data_lancamento date NOT NULL,
    historico character varying(255),
    conta_debito_id integer,
    conta_credito_id integer,
    valor numeric(14,2),
    CONSTRAINT chk_lancamentos_valor_positivo CHECK ((valor > (0)::numeric))
);


ALTER TABLE contabil.lancamentos OWNER TO postgres;

--
-- TOC entry 233 (class 1259 OID 25414)
-- Name: lancamentos_id_seq; Type: SEQUENCE; Schema: contabil; Owner: postgres
--

CREATE SEQUENCE contabil.lancamentos_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE contabil.lancamentos_id_seq OWNER TO postgres;

--
-- TOC entry 5091 (class 0 OID 0)
-- Dependencies: 233
-- Name: lancamentos_id_seq; Type: SEQUENCE OWNED BY; Schema: contabil; Owner: postgres
--

ALTER SEQUENCE contabil.lancamentos_id_seq OWNED BY contabil.lancamentos.id;


--
-- TOC entry 229 (class 1259 OID 25165)
-- Name: pagamentos; Type: TABLE; Schema: contabil; Owner: postgres
--

CREATE TABLE contabil.pagamentos (
    id_pagamentos integer NOT NULL,
    data_pagamento date NOT NULL,
    forma contabil.forma,
    id_reserva integer NOT NULL,
    valor_pago numeric(13,2) NOT NULL
);


ALTER TABLE contabil.pagamentos OWNER TO postgres;

--
-- TOC entry 228 (class 1259 OID 25164)
-- Name: pagamentos_id_pagamentos_seq; Type: SEQUENCE; Schema: contabil; Owner: postgres
--

CREATE SEQUENCE contabil.pagamentos_id_pagamentos_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE contabil.pagamentos_id_pagamentos_seq OWNER TO postgres;

--
-- TOC entry 5092 (class 0 OID 0)
-- Dependencies: 228
-- Name: pagamentos_id_pagamentos_seq; Type: SEQUENCE OWNED BY; Schema: contabil; Owner: postgres
--

ALTER SEQUENCE contabil.pagamentos_id_pagamentos_seq OWNED BY contabil.pagamentos.id_pagamentos;


--
-- TOC entry 232 (class 1259 OID 25402)
-- Name: plano_contas; Type: TABLE; Schema: contabil; Owner: postgres
--

CREATE TABLE contabil.plano_contas (
    id integer NOT NULL,
    codigo character varying(40) NOT NULL,
    nome_conta character varying(255) NOT NULL,
    tipo_conta contabil.tipo_conta_enum NOT NULL,
    natureza_conta contabil.natureza_conta_enum DEFAULT 'Devedora'::contabil.natureza_conta_enum NOT NULL
);


ALTER TABLE contabil.plano_contas OWNER TO postgres;

--
-- TOC entry 231 (class 1259 OID 25401)
-- Name: plano_contas_id_seq; Type: SEQUENCE; Schema: contabil; Owner: postgres
--

CREATE SEQUENCE contabil.plano_contas_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE contabil.plano_contas_id_seq OWNER TO postgres;

--
-- TOC entry 5093 (class 0 OID 0)
-- Dependencies: 231
-- Name: plano_contas_id_seq; Type: SEQUENCE OWNED BY; Schema: contabil; Owner: postgres
--

ALTER SEQUENCE contabil.plano_contas_id_seq OWNED BY contabil.plano_contas.id;


--
-- TOC entry 235 (class 1259 OID 25434)
-- Name: saldo_contas; Type: TABLE; Schema: contabil; Owner: postgres
--

CREATE TABLE contabil.saldo_contas (
    conta_id integer NOT NULL,
    saldo numeric(14,2) DEFAULT 0 NOT NULL,
    data_atualizacao timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE contabil.saldo_contas OWNER TO postgres;

--
-- TOC entry 237 (class 1259 OID 25476)
-- Name: vw_relatorio_financeiro; Type: VIEW; Schema: contabil; Owner: postgres
--

CREATE VIEW contabil.vw_relatorio_financeiro AS
 SELECT p.id_pagamentos,
    p.id_reserva,
    u.usuario AS usuario_cliente,
    p.data_pagamento,
    p.forma,
    r.status AS status_reserva,
    pac.nome AS pacote_escolhido,
    pac.preco AS preco_pacote,
    p.valor_pago AS valor_recebido
   FROM (((contabil.pagamentos p
     JOIN site.reservas r ON ((p.id_reserva = r.id_reserva)))
     JOIN admin.usuarios u ON ((r.fk_usuario = u.id_usuarios)))
     JOIN site.pacotes pac ON ((r.fk_local = pac.id_pacotes)));


ALTER VIEW contabil.vw_relatorio_financeiro OWNER TO postgres;

--
-- TOC entry 4911 (class 2604 OID 25418)
-- Name: lancamentos id; Type: DEFAULT; Schema: contabil; Owner: postgres
--

ALTER TABLE ONLY contabil.lancamentos ALTER COLUMN id SET DEFAULT nextval('contabil.lancamentos_id_seq'::regclass);


--
-- TOC entry 4908 (class 2604 OID 25168)
-- Name: pagamentos id_pagamentos; Type: DEFAULT; Schema: contabil; Owner: postgres
--

ALTER TABLE ONLY contabil.pagamentos ALTER COLUMN id_pagamentos SET DEFAULT nextval('contabil.pagamentos_id_pagamentos_seq'::regclass);


--
-- TOC entry 4909 (class 2604 OID 25405)
-- Name: plano_contas id; Type: DEFAULT; Schema: contabil; Owner: postgres
--

ALTER TABLE ONLY contabil.plano_contas ALTER COLUMN id SET DEFAULT nextval('contabil.plano_contas_id_seq'::regclass);


--
-- TOC entry 5084 (class 0 OID 25415)
-- Dependencies: 234
-- Data for Name: lancamentos; Type: TABLE DATA; Schema: contabil; Owner: postgres
--

INSERT INTO contabil.lancamentos VALUES (2, '2026-03-02', 'Compra de mercadorias para revenda a prazo', 4, 4, NULL);
INSERT INTO contabil.lancamentos VALUES (3, '2026-03-01', 'Aporte de capital dos sócios', 2, 12, NULL);
INSERT INTO contabil.lancamentos VALUES (4, '2026-03-02', 'Compra de mercadorias para revenda a prazo', 25, 8, NULL);
INSERT INTO contabil.lancamentos VALUES (5, '2026-03-03', 'Pagamento de aluguel do mês', 38, 1, NULL);
INSERT INTO contabil.lancamentos VALUES (6, '2026-03-03', 'Venda de mercadorias à vista', 1, 14, NULL);
INSERT INTO contabil.lancamentos VALUES (7, '2026-03-03', 'Custo das Mercadorias Vendidas', 16, 25, NULL);
INSERT INTO contabil.lancamentos VALUES (8, '2026-03-04', 'Venda de mercadorias a prazo', 3, 14, NULL);
INSERT INTO contabil.lancamentos VALUES (9, '2026-03-04', 'Custo das Mercadorias Vendidas', 16, 25, NULL);
INSERT INTO contabil.lancamentos VALUES (10, '2026-03-05', 'Compra de mercadorias à vista', 25, 2, NULL);
INSERT INTO contabil.lancamentos VALUES (11, '2026-03-05', 'Pagamento de conta de energia elétrica', 5, 39, NULL);
INSERT INTO contabil.lancamentos VALUES (12, '2026-03-06', 'Recebimento de cliente (venda dia 04)', 2, 3, NULL);
INSERT INTO contabil.lancamentos VALUES (13, '2026-03-07', 'Pagamento a fornecedor', 8, 2, NULL);
INSERT INTO contabil.lancamentos VALUES (14, '2026-03-08', 'Venda de mercadorias à vista', 1, 14, NULL);
INSERT INTO contabil.lancamentos VALUES (15, '2026-03-08', 'Custo das Mercadorias Vendidas', 36, 25, NULL);
INSERT INTO contabil.lancamentos VALUES (16, '2026-03-09', 'Pagamento de salários', 17, 2, NULL);
INSERT INTO contabil.lancamentos VALUES (17, '2026-03-09', 'Retenção de INSS/FGTS sobre a folha', 17, 10, NULL);
INSERT INTO contabil.lancamentos VALUES (18, '2026-03-10', 'Pagamento de telefone e internet', 21, 2, NULL);
INSERT INTO contabil.lancamentos VALUES (19, '2026-03-10', 'Compra de mercadorias a prazo', 25, 8, NULL);
INSERT INTO contabil.lancamentos VALUES (20, '2026-03-11', 'Venda de mercadorias a prazo', 3, 14, NULL);
INSERT INTO contabil.lancamentos VALUES (21, '2026-03-11', 'Custo das Mercadorias Vendidas', 36, 25, NULL);
INSERT INTO contabil.lancamentos VALUES (22, '2026-03-12', 'Pagamento de tarifas bancárias', 22, 2, NULL);
INSERT INTO contabil.lancamentos VALUES (23, '2026-03-12', 'Combustível para entregas', 23, 1, NULL);
INSERT INTO contabil.lancamentos VALUES (24, '2026-03-13', 'Recebimento de cliente', 2, 3, NULL);
INSERT INTO contabil.lancamentos VALUES (25, '2026-03-14', 'Venda de mercadorias à vista', 1, 14, NULL);
INSERT INTO contabil.lancamentos VALUES (26, '2026-03-14', 'Custo das Mercadorias Vendidas', 36, 25, NULL);
INSERT INTO contabil.lancamentos VALUES (27, '2026-03-15', 'Pagamento de água', 20, 2, NULL);
INSERT INTO contabil.lancamentos VALUES (28, '2026-03-15', 'Empréstimo bancário recebido', 2, 11, NULL);
INSERT INTO contabil.lancamentos VALUES (29, '2026-03-16', 'Compra de veículo para entregas, à vista', 27, 2, NULL);
INSERT INTO contabil.lancamentos VALUES (30, '2026-03-16', 'Compra de mercadorias a prazo', 25, 8, NULL);
INSERT INTO contabil.lancamentos VALUES (31, '2026-03-17', 'Venda de mercadorias a prazo', 3, 14, NULL);
INSERT INTO contabil.lancamentos VALUES (32, '2026-03-17', 'Custo das Mercadorias Vendidas', 36, 25, NULL);
INSERT INTO contabil.lancamentos VALUES (33, '2026-03-18', 'Pagamento a fornecedores', 8, 2, NULL);
INSERT INTO contabil.lancamentos VALUES (34, '2026-03-18', 'Prestação de serviço de instalação', 2, 15, NULL);
INSERT INTO contabil.lancamentos VALUES (35, '2026-03-19', 'Venda de mercadorias à vista', 1, 14, NULL);
INSERT INTO contabil.lancamentos VALUES (36, '2026-03-19', 'Custo Mercadorias Vendidas', 36, 25, NULL);
INSERT INTO contabil.lancamentos VALUES (37, '2026-03-20', 'Pagamento de parcela do empréstimo', 11, 2, NULL);
INSERT INTO contabil.lancamentos VALUES (38, '2026-03-20', 'Material de escritório', 24, 1, NULL);
INSERT INTO contabil.lancamentos VALUES (39, '2026-03-21', 'Recebimento de cliente', 2, 3, NULL);
INSERT INTO contabil.lancamentos VALUES (40, '2026-03-21', 'Venda de mercadorias a prazo', 3, 14, NULL);
INSERT INTO contabil.lancamentos VALUES (41, '2026-03-21', 'Custo das Mercadorias Vendidas', 36, 25, NULL);
INSERT INTO contabil.lancamentos VALUES (42, '2026-03-22', 'Compra de mercadorias à vista', 25, 1, NULL);
INSERT INTO contabil.lancamentos VALUES (43, '2026-03-23', 'Pagamento de tarifas bancárias', 22, 2, NULL);
INSERT INTO contabil.lancamentos VALUES (44, '2026-03-24', 'Venda de mercadorias à vista', 1, 14, NULL);
INSERT INTO contabil.lancamentos VALUES (45, '2026-03-24', 'Custo das Mercadorias Vendidas', 36, 25, NULL);
INSERT INTO contabil.lancamentos VALUES (46, '2026-03-25', 'Pagamento de impostos (Simples Nacional)', 10, 2, NULL);
INSERT INTO contabil.lancamentos VALUES (47, '2026-03-25', 'Venda de mercadorias à vista', 1, 14, NULL);
INSERT INTO contabil.lancamentos VALUES (48, '2026-03-25', 'Custo das Mercadorias Vendidas', 36, 25, NULL);
INSERT INTO contabil.lancamentos VALUES (49, '2026-03-26', 'Adiantamento de aluguel', 38, 2, NULL);
INSERT INTO contabil.lancamentos VALUES (50, '2026-03-27', 'Compra de mercadorias a prazo', 25, 8, NULL);
INSERT INTO contabil.lancamentos VALUES (51, '2026-03-28', 'Venda de mercadorias a prazo', 3, 14, NULL);
INSERT INTO contabil.lancamentos VALUES (52, '2026-03-28', 'Custo das Mercadorias Vendidas', 36, 25, NULL);
INSERT INTO contabil.lancamentos VALUES (53, '2026-03-29', 'Pagamento de salários', 17, 2, NULL);
INSERT INTO contabil.lancamentos VALUES (54, '2026-03-30', 'Recebimento de cliente', 2, 3, NULL);
INSERT INTO contabil.lancamentos VALUES (55, '2026-03-31', 'Despesas diversas do mês', 24, 24, NULL);
INSERT INTO contabil.lancamentos VALUES (56, '2026-04-01', 'Aporte de capital dos sócios', 2, 12, 30000.00);
INSERT INTO contabil.lancamentos VALUES (57, '2026-04-02', 'Compra de mercadorias à vista', 4, 2, 8000.00);
INSERT INTO contabil.lancamentos VALUES (58, '2026-04-03', 'Venda de mercadorias à vista', 1, 14, 5000.00);
INSERT INTO contabil.lancamentos VALUES (59, '2026-04-03', 'Baixa do custo da mercadoria vendida', 16, 4, 3000.00);
INSERT INTO contabil.lancamentos VALUES (60, '2026-04-05', 'Pagamento de aluguel do mês', 18, 2, 1500.00);
INSERT INTO contabil.lancamentos VALUES (61, '2026-04-06', 'Compra de mercadorias a prazo', 4, 8, 4000.00);


--
-- TOC entry 5080 (class 0 OID 25165)
-- Dependencies: 229
-- Data for Name: pagamentos; Type: TABLE DATA; Schema: contabil; Owner: postgres
--

INSERT INTO contabil.pagamentos VALUES (11, '2026-10-27', 'PIX', 1, 130.90);
INSERT INTO contabil.pagamentos VALUES (13, '2026-10-27', 'PIX', 2, 500.00);


--
-- TOC entry 5082 (class 0 OID 25402)
-- Dependencies: 232
-- Data for Name: plano_contas; Type: TABLE DATA; Schema: contabil; Owner: postgres
--

INSERT INTO contabil.plano_contas VALUES (1, '1.1.01', 'Caixa', 'Ativo', 'Devedora');
INSERT INTO contabil.plano_contas VALUES (2, '1.1.02', 'Bancos - Conta Movimento', 'Ativo', 'Devedora');
INSERT INTO contabil.plano_contas VALUES (3, '1.1.03', 'Clientes a Receber', 'Ativo', 'Devedora');
INSERT INTO contabil.plano_contas VALUES (4, '1.1.04', 'Estoque de Mercadorias', 'Ativo', 'Devedora');
INSERT INTO contabil.plano_contas VALUES (5, '1.1.04', 'Estoque de Mercadorias', 'Ativo', 'Devedora');
INSERT INTO contabil.plano_contas VALUES (6, '1.2.01', 'Móveis e Utensílios', 'Ativo', 'Devedora');
INSERT INTO contabil.plano_contas VALUES (7, '1.2.02', 'Veículos', 'Ativo', 'Devedora');
INSERT INTO contabil.plano_contas VALUES (8, '2.1.01', 'Fornecedores a Pagar', 'Passivo', 'Credora');
INSERT INTO contabil.plano_contas VALUES (9, '2.1.02', 'Salarios a Pagar', 'Passivo', 'Credora');
INSERT INTO contabil.plano_contas VALUES (10, '2.1.03', 'Impostos a Recolher', 'Passivo', 'Credora');
INSERT INTO contabil.plano_contas VALUES (11, '2.2.01', 'Emprestimos Bancarios (LP)', 'Passivo', 'Credora');
INSERT INTO contabil.plano_contas VALUES (12, '3.1.01', 'Capital Social', 'Patrimonio_liquido', 'Credora');
INSERT INTO contabil.plano_contas VALUES (13, '3.1.02', 'Lucros/Prejuízos Acumulados', 'Patrimonio_liquido', 'Credora');
INSERT INTO contabil.plano_contas VALUES (14, '4.1.01', 'Receita de Vendas', 'Receita', 'Credora');
INSERT INTO contabil.plano_contas VALUES (15, '4.1.02', 'Receita de Serviços', 'Receita', 'Credora');
INSERT INTO contabil.plano_contas VALUES (16, '5.1.01', 'Custo das Mercadorias Vendidas', 'Despesa', 'Devedora');
INSERT INTO contabil.plano_contas VALUES (17, '5.1.02', 'Despesas com Salários', 'Despesa', 'Devedora');
INSERT INTO contabil.plano_contas VALUES (18, '5.1.03', 'Despesas com Aluguel', 'Despesa', 'Devedora');
INSERT INTO contabil.plano_contas VALUES (19, '5.1.04', 'Despesas com Energia Eletrica', 'Despesa', 'Devedora');
INSERT INTO contabil.plano_contas VALUES (20, '5.1.05', 'Despesas com Água', 'Despesa', 'Devedora');
INSERT INTO contabil.plano_contas VALUES (21, '5.1.06', 'Despesas com Telefone/Internet', 'Despesa', 'Devedora');
INSERT INTO contabil.plano_contas VALUES (22, '5.1.07', 'Despesas Bancárias/Tarifas', 'Despesa', 'Devedora');
INSERT INTO contabil.plano_contas VALUES (23, '5.1.08', 'Despesas com Combustível', 'Despesa', 'Devedora');
INSERT INTO contabil.plano_contas VALUES (24, '5.1.09', 'Despesas Diversas', 'Despesa', 'Devedora');
INSERT INTO contabil.plano_contas VALUES (25, '1.1.04', 'Estoque de Mercadorias', 'Ativo', 'Devedora');
INSERT INTO contabil.plano_contas VALUES (26, '1.2.01', 'Móveis e Utensílios', 'Ativo', 'Devedora');
INSERT INTO contabil.plano_contas VALUES (27, '1.2.02', 'Veículos', 'Ativo', 'Devedora');
INSERT INTO contabil.plano_contas VALUES (28, '2.1.01', 'Fornecedores a Pagar', 'Passivo', 'Credora');
INSERT INTO contabil.plano_contas VALUES (29, '2.1.02', 'Salarios a Pagar', 'Passivo', 'Credora');
INSERT INTO contabil.plano_contas VALUES (30, '2.1.03', 'Impostos a Recolher', 'Passivo', 'Credora');
INSERT INTO contabil.plano_contas VALUES (31, '2.2.01', 'Emprestimos Bancarios (LP)', 'Passivo', 'Credora');
INSERT INTO contabil.plano_contas VALUES (32, '3.1.01', 'Capital Social', 'Patrimonio_liquido', 'Credora');
INSERT INTO contabil.plano_contas VALUES (33, '3.1.02', 'Lucros/Prejuízos Acumulados', 'Patrimonio_liquido', 'Credora');
INSERT INTO contabil.plano_contas VALUES (34, '4.1.01', 'Receita de Vendas', 'Receita', 'Credora');
INSERT INTO contabil.plano_contas VALUES (35, '4.1.02', 'Receita de Serviços', 'Receita', 'Credora');
INSERT INTO contabil.plano_contas VALUES (36, '5.1.01', 'Custo das Mercadorias Vendidas', 'Despesa', 'Devedora');
INSERT INTO contabil.plano_contas VALUES (37, '5.1.02', 'Despesas com Salários', 'Despesa', 'Devedora');
INSERT INTO contabil.plano_contas VALUES (38, '5.1.03', 'Despesas com Aluguel', 'Despesa', 'Devedora');
INSERT INTO contabil.plano_contas VALUES (39, '5.1.04', 'Despesas com Energia Eletrica', 'Despesa', 'Devedora');
INSERT INTO contabil.plano_contas VALUES (40, '5.1.05', 'Despesas com Água', 'Despesa', 'Devedora');
INSERT INTO contabil.plano_contas VALUES (41, '5.1.06', 'Despesas com Telefone/Internet', 'Despesa', 'Devedora');
INSERT INTO contabil.plano_contas VALUES (42, '5.1.07', 'Despesas Bancárias/Tarifas', 'Despesa', 'Devedora');
INSERT INTO contabil.plano_contas VALUES (43, '5.1.08', 'Despesas com Combustível', 'Despesa', 'Devedora');
INSERT INTO contabil.plano_contas VALUES (44, '5.1.09', 'Despesas Diversas', 'Despesa', 'Devedora');


--
-- TOC entry 5085 (class 0 OID 25434)
-- Dependencies: 235
-- Data for Name: saldo_contas; Type: TABLE DATA; Schema: contabil; Owner: postgres
--

INSERT INTO contabil.saldo_contas VALUES (3, 0.00, '2026-11-05 18:46:10.394163');
INSERT INTO contabil.saldo_contas VALUES (5, 0.00, '2026-11-05 18:46:10.394163');
INSERT INTO contabil.saldo_contas VALUES (6, 0.00, '2026-11-05 18:46:10.394163');
INSERT INTO contabil.saldo_contas VALUES (7, 0.00, '2026-11-05 18:46:10.394163');
INSERT INTO contabil.saldo_contas VALUES (9, 0.00, '2026-11-05 18:46:10.394163');
INSERT INTO contabil.saldo_contas VALUES (10, 0.00, '2026-11-05 18:46:10.394163');
INSERT INTO contabil.saldo_contas VALUES (11, 0.00, '2026-11-05 18:46:10.394163');
INSERT INTO contabil.saldo_contas VALUES (13, 0.00, '2026-11-05 18:46:10.394163');
INSERT INTO contabil.saldo_contas VALUES (15, 0.00, '2026-11-05 18:46:10.394163');
INSERT INTO contabil.saldo_contas VALUES (17, 0.00, '2026-11-05 18:46:10.394163');
INSERT INTO contabil.saldo_contas VALUES (19, 0.00, '2026-11-05 18:46:10.394163');
INSERT INTO contabil.saldo_contas VALUES (20, 0.00, '2026-11-05 18:46:10.394163');
INSERT INTO contabil.saldo_contas VALUES (21, 0.00, '2026-11-05 18:46:10.394163');
INSERT INTO contabil.saldo_contas VALUES (22, 0.00, '2026-11-05 18:46:10.394163');
INSERT INTO contabil.saldo_contas VALUES (23, 0.00, '2026-11-05 18:46:10.394163');
INSERT INTO contabil.saldo_contas VALUES (24, 0.00, '2026-11-05 18:46:10.394163');
INSERT INTO contabil.saldo_contas VALUES (25, 0.00, '2026-11-05 18:46:10.394163');
INSERT INTO contabil.saldo_contas VALUES (26, 0.00, '2026-11-05 18:46:10.394163');
INSERT INTO contabil.saldo_contas VALUES (27, 0.00, '2026-11-05 18:46:10.394163');
INSERT INTO contabil.saldo_contas VALUES (28, 0.00, '2026-11-05 18:46:10.394163');
INSERT INTO contabil.saldo_contas VALUES (29, 0.00, '2026-11-05 18:46:10.394163');
INSERT INTO contabil.saldo_contas VALUES (30, 0.00, '2026-11-05 18:46:10.394163');
INSERT INTO contabil.saldo_contas VALUES (31, 0.00, '2026-11-05 18:46:10.394163');
INSERT INTO contabil.saldo_contas VALUES (32, 0.00, '2026-11-05 18:46:10.394163');
INSERT INTO contabil.saldo_contas VALUES (33, 0.00, '2026-11-05 18:46:10.394163');
INSERT INTO contabil.saldo_contas VALUES (34, 0.00, '2026-11-05 18:46:10.394163');
INSERT INTO contabil.saldo_contas VALUES (35, 0.00, '2026-11-05 18:46:10.394163');
INSERT INTO contabil.saldo_contas VALUES (36, 0.00, '2026-11-05 18:46:10.394163');
INSERT INTO contabil.saldo_contas VALUES (37, 0.00, '2026-11-05 18:46:10.394163');
INSERT INTO contabil.saldo_contas VALUES (38, 0.00, '2026-11-05 18:46:10.394163');
INSERT INTO contabil.saldo_contas VALUES (39, 0.00, '2026-11-05 18:46:10.394163');
INSERT INTO contabil.saldo_contas VALUES (40, 0.00, '2026-11-05 18:46:10.394163');
INSERT INTO contabil.saldo_contas VALUES (41, 0.00, '2026-11-05 18:46:10.394163');
INSERT INTO contabil.saldo_contas VALUES (42, 0.00, '2026-11-05 18:46:10.394163');
INSERT INTO contabil.saldo_contas VALUES (43, 0.00, '2026-11-05 18:46:10.394163');
INSERT INTO contabil.saldo_contas VALUES (44, 0.00, '2026-11-05 18:46:10.394163');
INSERT INTO contabil.saldo_contas VALUES (12, 30000.00, '2026-11-05 18:46:10.394163');
INSERT INTO contabil.saldo_contas VALUES (1, 5000.00, '2026-11-05 18:46:10.394163');
INSERT INTO contabil.saldo_contas VALUES (14, 5000.00, '2026-11-05 18:46:10.394163');
INSERT INTO contabil.saldo_contas VALUES (16, 3000.00, '2026-11-05 18:46:10.394163');
INSERT INTO contabil.saldo_contas VALUES (18, 1500.00, '2026-11-05 18:46:10.394163');
INSERT INTO contabil.saldo_contas VALUES (2, 20500.00, '2026-11-05 18:46:10.394163');
INSERT INTO contabil.saldo_contas VALUES (4, 9000.00, '2026-11-05 18:46:10.394163');
INSERT INTO contabil.saldo_contas VALUES (8, 4000.00, '2026-11-05 18:46:10.394163');


--
-- TOC entry 5094 (class 0 OID 0)
-- Dependencies: 233
-- Name: lancamentos_id_seq; Type: SEQUENCE SET; Schema: contabil; Owner: postgres
--

SELECT pg_catalog.setval('contabil.lancamentos_id_seq', 61, true);


--
-- TOC entry 5095 (class 0 OID 0)
-- Dependencies: 228
-- Name: pagamentos_id_pagamentos_seq; Type: SEQUENCE SET; Schema: contabil; Owner: postgres
--

SELECT pg_catalog.setval('contabil.pagamentos_id_pagamentos_seq', 15, true);


--
-- TOC entry 5096 (class 0 OID 0)
-- Dependencies: 231
-- Name: plano_contas_id_seq; Type: SEQUENCE SET; Schema: contabil; Owner: postgres
--

SELECT pg_catalog.setval('contabil.plano_contas_id_seq', 44, true);


--
-- TOC entry 4920 (class 2606 OID 25422)
-- Name: lancamentos lancamentos_pkey; Type: CONSTRAINT; Schema: contabil; Owner: postgres
--

ALTER TABLE ONLY contabil.lancamentos
    ADD CONSTRAINT lancamentos_pkey PRIMARY KEY (id);


--
-- TOC entry 4916 (class 2606 OID 25173)
-- Name: pagamentos pagamentos_pkey; Type: CONSTRAINT; Schema: contabil; Owner: postgres
--

ALTER TABLE ONLY contabil.pagamentos
    ADD CONSTRAINT pagamentos_pkey PRIMARY KEY (id_pagamentos);


--
-- TOC entry 4918 (class 2606 OID 25413)
-- Name: plano_contas plano_contas_pkey; Type: CONSTRAINT; Schema: contabil; Owner: postgres
--

ALTER TABLE ONLY contabil.plano_contas
    ADD CONSTRAINT plano_contas_pkey PRIMARY KEY (id);


--
-- TOC entry 4922 (class 2606 OID 25443)
-- Name: saldo_contas saldo_contas_pkey; Type: CONSTRAINT; Schema: contabil; Owner: postgres
--

ALTER TABLE ONLY contabil.saldo_contas
    ADD CONSTRAINT saldo_contas_pkey PRIMARY KEY (conta_id);


--
-- TOC entry 4928 (class 2620 OID 25450)
-- Name: lancamentos trg_atualiza_saldo; Type: TRIGGER; Schema: contabil; Owner: postgres
--

CREATE TRIGGER trg_atualiza_saldo AFTER INSERT ON contabil.lancamentos FOR EACH ROW EXECUTE FUNCTION contabil.fn_atualiza_saldo();


--
-- TOC entry 4927 (class 2620 OID 25355)
-- Name: pagamentos trg_validar_pagamento_reserva; Type: TRIGGER; Schema: contabil; Owner: postgres
--

CREATE TRIGGER trg_validar_pagamento_reserva BEFORE INSERT OR UPDATE OF id_reserva ON contabil.pagamentos FOR EACH ROW EXECUTE FUNCTION contabil.fn_validar_pagamento_reserva();


--
-- TOC entry 4923 (class 2606 OID 25187)
-- Name: pagamentos fk_pagamento_reserva; Type: FK CONSTRAINT; Schema: contabil; Owner: postgres
--

ALTER TABLE ONLY contabil.pagamentos
    ADD CONSTRAINT fk_pagamento_reserva FOREIGN KEY (id_reserva) REFERENCES site.reservas(id_reserva) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 4924 (class 2606 OID 25428)
-- Name: lancamentos lancamentos_conta_credito_id_fkey; Type: FK CONSTRAINT; Schema: contabil; Owner: postgres
--

ALTER TABLE ONLY contabil.lancamentos
    ADD CONSTRAINT lancamentos_conta_credito_id_fkey FOREIGN KEY (conta_credito_id) REFERENCES contabil.plano_contas(id);


--
-- TOC entry 4925 (class 2606 OID 25423)
-- Name: lancamentos lancamentos_conta_debito_id_fkey; Type: FK CONSTRAINT; Schema: contabil; Owner: postgres
--

ALTER TABLE ONLY contabil.lancamentos
    ADD CONSTRAINT lancamentos_conta_debito_id_fkey FOREIGN KEY (conta_debito_id) REFERENCES contabil.plano_contas(id);


--
-- TOC entry 4926 (class 2606 OID 25444)
-- Name: saldo_contas saldo_contas_conta_id_fkey; Type: FK CONSTRAINT; Schema: contabil; Owner: postgres
--

ALTER TABLE ONLY contabil.saldo_contas
    ADD CONSTRAINT saldo_contas_conta_id_fkey FOREIGN KEY (conta_id) REFERENCES contabil.plano_contas(id);


-- Completed on 2026-11-13 17:02:28

--
-- PostgreSQL database dump complete
--

\unrestrict wpYH5UsTcuKuknYIi9Kzbqjtf3Q0ITd22mgZpEQVXeVPq1kiS6l58V9bCPCCL2x


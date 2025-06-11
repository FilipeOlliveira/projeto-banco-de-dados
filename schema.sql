CREATE TABLE pacientes (
    id_paciente SERIAL PRIMARY KEY,
    nome TEXT NOT NULL,
    cpf VARCHAR(14) UNIQUE NOT NULL,
    data_nascimento DATE NOT NULL,
    sexo CHAR(1),
    telefone TEXT,
    email TEXT,
    endereco TEXT
);

CREATE TABLE medicos (
    id_medico SERIAL PRIMARY KEY,
    nome TEXT NOT NULL,
    crm VARCHAR(20) UNIQUE NOT NULL,
    telefone TEXT,
    email TEXT
);

CREATE TABLE especialidades (
    id_especialidade SERIAL PRIMARY KEY,
    nome TEXT NOT NULL,
    descricao TEXT
);

CREATE TABLE medico_especialidade (
    id_medico INT REFERENCES medicos(id_medico),
    id_especialidade INT REFERENCES especialidades(id_especialidade),
    PRIMARY KEY (id_medico, id_especialidade)
);

CREATE TABLE consultas (
    id_consulta SERIAL PRIMARY KEY,
    id_paciente INT REFERENCES pacientes(id_paciente),
    id_medico INT REFERENCES medicos(id_medico),
    data_hora TIMESTAMP NOT NULL,
    observacoes TEXT,
    valor NUMERIC(10,2),
    status VARCHAR(20) DEFAULT 'agendada'
);

CREATE TABLE receitas (
    id_receita SERIAL PRIMARY KEY,
    id_consulta INT REFERENCES consultas(id_consulta),
    descricao TEXT NOT NULL,
    data_emissao DATE DEFAULT CURRENT_DATE
);

CREATE TABLE exames (
    id_exame SERIAL PRIMARY KEY,
    id_consulta INT REFERENCES consultas(id_consulta),
    tipo TEXT NOT NULL,
    descricao TEXT,
    data_solicitacao DATE DEFAULT CURRENT_DATE,
    resultado TEXT
);

CREATE TABLE convenios (
s    id_convenio SERIAL PRIMARY KEY,
    nome TEXT NOT NULL,
    cnpj VARCHAR(18) UNIQUE NOT NULL,
    telefone TEXT
);

CREATE TABLE medico_convenio (
    id_medico INT REFERENCES medicos(id_medico),
    id_convenio INT REFERENCES convenios(id_convenio),
    PRIMARY KEY (id_medico, id_convenio)
);

CREATE OR REPLACE FUNCTION sp_marcar_consulta(
    pid_paciente INT,
    pid_medico INT,
    pdata_hora TIMESTAMP,
    pvalor NUMERIC
)
RETURNS VOID AS $$
BEGIN
    INSERT INTO consultas (id_paciente, id_medico, data_hora, valor)
    VALUES (pid_paciente, pid_medico, pdata_hora, pvalor);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION sp_emitir_receita(
    pid_consulta INT,
    pdescricao TEXT
)
RETURNS VOID AS $$
BEGIN
    INSERT INTO receitas (id_consulta, descricao)
    VALUES (pid_consulta, pdescricao);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION sp_registrar_resultado_exame(
    pid_exame INT,
    presultado TEXT
)
RETURNS VOID AS $$
BEGIN
    UPDATE exames SET resultado = presultado
    WHERE id_exame = pid_exame;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION sp_cancelar_consulta(
    pid_consulta INT
)
RETURNS VOID AS $$
BEGIN
    UPDATE consultas SET status = 'cancelada'
    WHERE id_consulta = pid_consulta;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION valida_medico_convenio()
RETURNS TRIGGER AS $$
DECLARE
    tem_convenio INT;
BEGIN
    SELECT COUNT(*) INTO tem_convenio
    FROM medico_convenio mc
    JOIN pacientes p ON p.id_paciente = NEW.id_paciente
    WHERE mc.id_medico = NEW.id_medico;

    IF tem_convenio = 0 THEN
        RAISE EXCEPTION 'Médico não atende o convênio do paciente';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TABLE log_consultas (
    id_log SERIAL PRIMARY KEY,
    id_consulta INT,
    data_criacao TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE OR REPLACE FUNCTION log_nova_consulta()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO log_consultas (id_consulta)
    VALUES (NEW.id_consulta);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_log_consulta
AFTER INSERT ON consultas
FOR EACH ROW
EXECUTE FUNCTION log_nova_consulta();

CREATE OR REPLACE FUNCTION verifica_consultas_antes_delete()
RETURNS TRIGGER AS $$
DECLARE
    qtd_consultas INT;
BEGIN
    SELECT COUNT(*) INTO qtd_consultas
    FROM consultas
    WHERE id_medico = OLD.id_medico AND data_hora > NOW();

    IF qtd_consultas > 0 THEN
        RAISE EXCEPTION 'Médico possui consultas futuras e não pode ser excluído';
    END IF;

    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_bloqueia_delete_medico
BEFORE DELETE ON medicos
FOR EACH ROW
EXECUTE FUNCTION verifica_consultas_antes_delete();



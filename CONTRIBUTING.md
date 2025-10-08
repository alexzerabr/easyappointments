# 🤝 Guia de Contribuição

> **Como contribuir para o EasyAppointments + WPPConnect Integration**

---

## 📋 Índice

- [Bem-vindo!](#bem-vindo)
- [Primeiros Passos](#primeiros-passos)
- [Workflow de Desenvolvimento](#workflow-de-desenvolvimento)
- [Padrões de Código](#padrões-de-código)
- [Processo de Pull Request](#processo-de-pull-request)
- [Testes](#testes)
- [Documentação](#documentação)
- [Comunidade](#comunidade)

---

## 👋 Bem-vindo!

Obrigado pelo interesse em contribuir para o projeto! Este guia ajudará você a:
- ✅ Configurar ambiente de desenvolvimento
- ✅ Entender o workflow do projeto
- ✅ Seguir os padrões de código
- ✅ Enviar suas contribuições

---

## 🚀 Primeiros Passos

### 1. Fork e Clone

```bash
# 1. Fork o repositório no GitHub
# (clique no botão "Fork" na página do projeto)

# 2. Clone seu fork
git clone https://github.com/SEU-USUARIO/easyappointments.git
cd easyappointments

# 3. Adicione o repositório original como upstream
git remote add upstream https://github.com/alexzerabr/easyappointments.git

# 4. Verifique os remotes
git remote -v
```

### 2. Setup do Ambiente de Desenvolvimento

```bash
# Iniciar ambiente Docker de desenvolvimento
./deploy/deploy-development.sh up

# Aguardar serviços ficarem prontos (1-2 minutos)
# Acessar: http://localhost
```

**Pronto para desenvolver!** 🎉

---

## 🔄 Workflow de Desenvolvimento

### 1. Criar Branch para Feature/Fix

```bash
# Sempre crie uma branch a partir da main atualizada
git checkout main
git pull upstream main

# Criar branch com nome descritivo
git checkout -b feature/nova-funcionalidade
# ou
git checkout -b fix/correcao-bug
# ou
git checkout -b docs/atualizar-readme
```

**Convenção de nomes de branches:**
- `feature/` - Nova funcionalidade
- `fix/` - Correção de bug
- `docs/` - Atualização de documentação
- `refactor/` - Refatoração de código
- `test/` - Adição/correção de testes

### 2. Desenvolver e Testar

```bash
# Fazer alterações no código
# Testar localmente

# Ver logs em tempo real
./deploy/deploy-development.sh logs -f

# Verificar saúde
./deploy/deploy-development.sh health
```

### 3. Commit das Mudanças

```bash
# Adicionar arquivos alterados
git add .

# Commit com mensagem descritiva
git commit -m "feat: adiciona integração com novo serviço WhatsApp"
```

**Convenção de commits (Conventional Commits):**
- `feat:` - Nova funcionalidade
- `fix:` - Correção de bug
- `docs:` - Documentação
- `style:` - Formatação (sem mudança de código)
- `refactor:` - Refatoração
- `test:` - Testes
- `chore:` - Manutenção/tarefas

**Exemplos:**
```
feat: adiciona suporte a templates de mensagem
fix: corrige erro ao enviar mensagem com emoji
docs: atualiza guia de instalação
refactor: melhora performance do agendamento
```

### 4. Push e Pull Request

```bash
# Push da branch para seu fork
git push origin feature/nova-funcionalidade
```

**Criar Pull Request:**
1. Acesse seu fork no GitHub
2. Clique em "Compare & pull request"
3. Preencha o template de PR
4. Aguarde review

---

## 📝 Padrões de Código

### PHP (CodeIgniter 3)

**Estilo:**
- PSR-12 coding style
- Indentação: 4 espaços
- Abertura de chaves na mesma linha

**Exemplo:**
```php
<?php

class Appointments_model extends EA_Model
{
    public function save(array $appointment): int
    {
        if (empty($appointment['id'])) {
            return $this->insert($appointment);
        }
        
        return $this->update($appointment);
    }
}
```

### JavaScript

**Estilo:**
- ESLint padrão do projeto
- Indentação: 4 espaços
- Usar `const` e `let` (não `var`)
- Preferir arrow functions

**Exemplo:**
```javascript
const appointmentService = {
    save: (appointment) => {
        return fetch('/api/appointments', {
            method: 'POST',
            body: JSON.stringify(appointment),
            headers: {'Content-Type': 'application/json'}
        });
    }
};
```

### SQL

**Convenções:**
- UPPERCASE para palavras-chave SQL
- snake_case para nomes de tabelas e colunas
- Usar migrations para alterações de schema

**Exemplo:**
```sql
SELECT 
    a.id,
    a.start_datetime,
    c.first_name,
    c.last_name
FROM ea_appointments a
INNER JOIN ea_users c ON a.id_users_customer = c.id
WHERE a.start_datetime >= NOW()
ORDER BY a.start_datetime ASC;
```

---

## 🔍 Processo de Pull Request

### Checklist Antes de Enviar PR

- [ ] Código segue os padrões do projeto
- [ ] Testes passam localmente
- [ ] Documentação atualizada (se necessário)
- [ ] Commit messages seguem convenção
- [ ] Branch está atualizada com main
- [ ] Sem conflitos de merge

### Template de Pull Request

```markdown
## Descrição
[Descreva o que foi implementado/corrigido]

## Tipo de Mudança
- [ ] 🐛 Bug fix
- [ ] ✨ Nova feature
- [ ] 📝 Documentação
- [ ] 🔧 Refatoração
- [ ] ⚡ Performance

## Testes
[Como testar as mudanças]

## Screenshots (se aplicável)
[Adicione screenshots/gifs se for mudança visual]

## Checklist
- [ ] Código segue padrões do projeto
- [ ] Testes passam
- [ ] Documentação atualizada
```

### Processo de Review

1. **Automated Checks**: CI/CD executa testes automaticamente
2. **Code Review**: Mantenedor revisa o código
3. **Feedback**: Podem ser solicitadas mudanças
4. **Aprovação**: Após aprovação, PR é merged

---

## ✅ Testes

### Executar Testes

```bash
# Testes unitários PHP
composer test

# Testes específicos
./vendor/bin/phpunit tests/Unit/AppointmentsTest.php

# Ver cobertura
composer test -- --coverage-html coverage/
```

### Escrever Testes

**Localização:** `tests/Unit/`

**Exemplo:**
```php
<?php

namespace EA\Tests\Unit;

use PHPUnit\Framework\TestCase;

class AppointmentsTest extends TestCase
{
    public function test_can_create_appointment()
    {
        $appointment = [
            'start_datetime' => '2025-10-05 10:00:00',
            'end_datetime' => '2025-10-05 11:00:00',
            'id_users_customer' => 1,
            'id_users_provider' => 2,
            'id_services' => 3
        ];
        
        // Test implementation
        $this->assertNotEmpty($appointment);
    }
}
```

---

## 📚 Documentação

### Onde Documentar

| Tipo de Mudança | Documentar Em |
|-----------------|---------------|
| Nova feature | README.md + docs relevantes |
| API changes | docs/rest-api.md |
| Deploy changes | DEPLOY.md |
| Build changes | BUILD.md |
| Docker changes | docs/docker.md |

### Estilo de Documentação

- **Claro e conciso**
- **Exemplos práticos**
- **Screenshots quando útil**
- **Links para referências**

---

## 🌍 Comunidade

### Canais de Comunicação

- **GitHub Issues**: Reportar bugs e solicitar features
- **GitHub Discussions**: Discussões gerais
- **Pull Requests**: Contribuições de código

### Código de Conduta

- ✅ Seja respeitoso e profissional
- ✅ Aceite feedback construtivo
- ✅ Foque no problema, não na pessoa
- ✅ Ajude outros contribuidores

### Reportar Bugs

**Use o template de issue:**

```markdown
**Descrição do Bug**
[Descrição clara do problema]

**Passos para Reproduzir**
1. Vá para '...'
2. Clique em '....'
3. Veja o erro

**Comportamento Esperado**
[O que deveria acontecer]

**Comportamento Atual**
[O que realmente acontece]

**Screenshots**
[Se aplicável]

**Ambiente:**
 - OS: [e.g. Ubuntu 22.04]
 - Browser: [e.g. Chrome 120]
 - Versão: [e.g. 1.5.0]
```

### Solicitar Features

**Use o template de feature request:**

```markdown
**Descrição da Feature**
[Descrição clara da funcionalidade desejada]

**Problema que Resolve**
[Qual problema esta feature resolveria]

**Solução Proposta**
[Como você imagina que funcione]

**Alternativas Consideradas**
[Outras abordagens que você considerou]
```

---

## 🔗 Referências Úteis

### Documentação do Projeto

- [README.md](README.md) - Visão geral
- [DEPLOY.md](DEPLOY.md) - Guia de deploy
- [BUILD.md](BUILD.md) - Guia de build
- [docs/](docs/) - Documentação técnica completa

### Recursos Externos

- [Easy!Appointments Oficial](https://easyappointments.org/)
- [CodeIgniter 3 Guide](https://codeigniter.com/userguide3/)
- [WPPConnect Docs](https://wppconnect.io/)
- [Conventional Commits](https://www.conventionalcommits.org/)

### Links Úteis

- [PSR-12 Coding Style](https://www.php-fig.org/psr/psr-12/)
- [Git Best Practices](https://git-scm.com/book/en/v2)
- [Docker Documentation](https://docs.docker.com/)

---

## 🎓 Aprendendo o Projeto

### Arquitetura

```
application/
├── controllers/     # Lógica de controle
├── models/          # Acesso a dados
├── views/           # Templates HTML
├── libraries/       # Bibliotecas customizadas
└── helpers/         # Funções auxiliares

assets/
├── css/             # Estilos SCSS
├── js/              # JavaScript
└── vendor/          # Bibliotecas externas

docs/                # Documentação técnica
tests/               # Testes automatizados
docker/              # Configurações Docker
```

### Principais Componentes

- **Backend**: CodeIgniter 3 (PHP)
- **Frontend**: jQuery + Bootstrap 5
- **Database**: MySQL 8.0
- **WhatsApp**: WPPConnect integration
- **Containerização**: Docker + Docker Compose

---

## 💡 Dicas para Contribuidores

### Boas Práticas

1. **Commits pequenos e focados** - Um commit = uma mudança lógica
2. **Testar localmente** - Sempre teste antes de push
3. **Atualizar branch** - Mantenha sua branch sincronizada com main
4. **Revisar seu próprio código** - Revise suas mudanças antes do PR
5. **Documentar quando necessário** - Não deixe código sem documentação

### Primeiras Contribuições

Procure por issues marcadas como:
- `good first issue` - Boas para iniciantes
- `help wanted` - Ajuda necessária
- `documentation` - Melhorias em docs

### Tornando-se Mantenedor

Contribuições consistentes e de qualidade podem levar a:
- Acesso de commit ao repositório
- Participação em decisões de arquitetura
- Reconhecimento como contribuidor principal

---

## ❓ Dúvidas?

- **Dúvidas gerais**: Abra uma Discussion no GitHub
- **Problemas técnicos**: Abra uma Issue
- **Contribuições**: Envie um Pull Request

---

**Obrigado por contribuir!** 🎉

Sua contribuição torna este projeto melhor para toda a comunidade.

---

**Versão:** 1.0  
**Última Atualização:** Outubro 2025

